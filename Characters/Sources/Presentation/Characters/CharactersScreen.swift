import Core
import Networking
import Storage
import SwiftUI

struct CharactersScreen<Content: View, Detail: View>: View {
    // `Owned`, not a directly-observed `@StateObject`: the view model must not
    // trigger this body on every `@Published` write, only the sections should.
    @StateObject private var scope: Owned<DependencyContainer>
    private let makeSection: (DependencyContainer, CharactersLayout) -> Content

    /// Builds the pushed character detail for a character id, so a test or preview can
    /// push a stub detail without a container.
    private let makeDetail: (String) -> Detail

    /// Write-only mirror of the search field for `.searchable`'s binding; the view model
    /// never learns about it, so the screen stays non-observing.
    @State private var searchText = ""

    /// Which of the two results sections is on screen. Not persisted: a relaunch
    /// resetting the toggle is cheaper than a `UserDefaults` key to own and test.
    @State private var layout: CharactersLayout = .grid

    init(makeScope: @escaping () -> DependencyContainer,
         makeSection: @escaping (DependencyContainer, CharactersLayout) -> Content,
         makeDetail: @escaping (String) -> Detail) {
        _scope = StateObject(wrappedValue: Owned(makeScope))
        self.makeSection = makeSection
        self.makeDetail = makeDetail
    }

    private var viewModel: any CharactersViewModelContract {
        scope.value.resolve((any CharactersViewModelContract).self)
    }

    private var navigator: CharactersNavigator {
        scope.value.resolve(CharactersNavigator.self)
    }

    var body: some View {
        // Bound to the navigator's `path` (via `Bindable`) rather than a local `@State`:
        // taps and deep links both write into the same array, one source of truth.
        NavigationStack(path: Bindable(navigator).path) {
            makeSection(scope.value, layout)
                .navigationDestination(for: CharactersRoute.self) { route in
                    switch route {
                    case .detail(let id):
                        makeDetail(id)
                    }
                }
                .navigationTitle(Text("Characters", bundle: .module))
                .searchable(text: $searchText,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: Text("Search by name", bundle: .module))
                // Character names are proper nouns; autocorrect would rewrite them.
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: searchText) { _, text in
                    // Debounced in the view model, not here: a `.task(id:)` here would be
                    // cancelled by the re-render each keystroke causes.
                    viewModel.updateSearchText(text)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            layout = layout.toggled
                        } label: {
                            Label(layout.toggleTitle, systemImage: layout.toggleSystemImage)
                        }
                    }
                }
                // A cache clear from the developer tools is announced via `Storage`
                // notification; the screen answers by reloading from scratch.
                .onReceive(NotificationCenter.default.publisher(for: .cacheDidClear)) { _ in
                    Task { await viewModel.reloadFromScratch() }
                }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

#Preview {
    CharactersScreen(
        makeScope: {
            let root = DependencyContainer()
            CharactersAssembly.register(in: root,
                                        dependencies: PreviewCharactersDependencies(),
                                        navigator: CharactersNavigator())
            // Last wins: the real wiring, cut off at the repository so nothing reaches the network.
            root.register((any CharactersRepositoryContract).self) { _ in PreviewCharactersRepository() }
            return root.makeChild()
        },
        makeSection: { scope, layout in
            VStack(spacing: 0) {
                CharactersFilterBarSectionView(
                    viewModel: scope.resolve((any CharactersFilterBarSectionViewModelContract).self),
                    renderModelPublisher: scope.resolve(CharactersFilterBarSectionMapper.self).renderModelPublisher()
                )
                switch layout {
                case .list:
                    CharactersListSectionView(
                        viewModel: scope.resolve((any CharactersListSectionViewModelContract).self),
                        renderModelPublisher: scope.resolve(CharactersListSectionMapper.self).renderModelPublisher()
                    )
                case .grid:
                    CharactersGridSectionView(
                        viewModel: scope.resolve((any CharactersGridSectionViewModelContract).self),
                        renderModelPublisher: scope.resolve(CharactersGridSectionMapper.self).renderModelPublisher()
                    )
                }
            }
        },
        // Placeholder detail: this preview is for the list, and a real one needs a container.
        makeDetail: { id in
            Text("Character \(id)")
        }
    )
}

/// Feeds `CharactersAssembly` in the preview; every registration that would use these is overridden.
private struct PreviewCharactersDependencies: CharactersDependencies {
    let graphQLClient = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!)
    let justWatchClient = GraphQLClient(endpoint: URL(string: "https://example.com/justwatch")!)
    let cacheStore: any CacheStoreContract = PreviewCacheStore()
}

/// Stores nothing: the preview never reaches the cache, but the wiring still asks for a store.
private struct PreviewCacheStore: CacheStoreContract {
    func entry<Value: Codable & Sendable>(for key: CacheKey, as type: Value.Type) async throws -> CacheEntry<Value>? { nil }
    func store<Value: Codable & Sendable>(_ value: Value, for key: CacheKey, lifetime: TimeInterval) async throws {}
    func remove(_ key: CacheKey) async throws {}
    func removeAll(in namespace: String) async throws {}
    func removeExpired() async throws {}
}

/// Stands in for the repository, skipping the cache, network and mapper. Serves three pages
/// so the footer, append and end of list are reachable in the canvas, and filters in memory
/// so the search bar, chips and empty state are all exercisable without a network.
private struct PreviewCharactersRepository: CharactersRepositoryContract {
    private static let pageCount = 3
    private static let names = ["Rick Sanchez", "Morty Smith", "Summer Smith",
                                "Beth Smith", "Jerry Smith", "Birdperson"]

    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage {
        let characters = Self.names.enumerated().map { index, name in
            // Ids must be unique across pages: `List` keys rows on them.
            let number = (page - 1) * Self.names.count + index + 1
            return CharacterModel(id: "\(number)",
                                  name: "\(name) (page \(page))",
                                  status: index.isMultiple(of: 2) ? .alive : .dead,
                                  species: "Human",
                                  image: URL(string: "https://rickandmortyapi.com/api/character/avatar/\(number).jpeg")!,
                                  location: CharacterLocation(name: "C-137", dimension: nil))
        }
        .filter { character in
            let matchesName = filter.name.map { character.name.localizedStandardContains($0) } ?? true
            let matchesStatus = filter.status.map { $0 == character.status } ?? true
            return matchesName && matchesStatus
        }
        return CharactersPage(characters: characters,
                              nextPage: page < Self.pageCount ? page + 1 : nil)
    }

    /// Never called: this preview never pushes the real detail.
    func fetchCharacterDetail(id: String) async throws -> CharacterDetailModel {
        throw CancellationError()
    }

    func fetchHBOMaxLinks() async throws -> HBOMaxLinks {
        .empty
    }
}
