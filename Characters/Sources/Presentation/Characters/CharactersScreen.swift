import Core
import Storage
import SwiftUI

struct CharactersScreen<Content: View>: View {
    // The graph lives in `Owned` rather than the view model living directly in
    // `@StateObject`: `@StateObject` is what keeps the graph alive for the
    // screen's identity, but it also observes. An observable view model would
    // fire `objectWillChange` on every `@Published` write and re-evaluate this
    // whole body, while the architecture wants only the sections to re-render
    // (view model publishers -> mapper -> section `@State`). `Owned` never
    // publishes anything, so we get the ownership without the observation.
    @StateObject private var graph: Owned<CharactersScreenGraph>
    private let makeSection: (CharactersScreenGraph, CharactersLayout) -> Content

    /// The search field's text, owned by the screen.
    ///
    /// `.searchable` needs a `Binding`, and the only two-way binding available
    /// without observation is local `@State`. It is a *write-only* mirror: the
    /// screen pushes each change into the view model and never reads anything
    /// back, so this stays consistent with the screen not observing the view
    /// model — the rows still arrive through the mapper.
    @State private var searchText = ""

    /// Which of the two results sections is on screen.
    ///
    /// Plain `@State`, per screen identity, starting at the list: a preference
    /// the user has to re-toggle after a relaunch is a small price against
    /// a `UserDefaults` key the feature would then have to own, migrate and
    /// reset in tests. Like `searchText`, it is view state the view model never
    /// learns about, so the screen stays non-observing.
    @State private var layout: CharactersLayout = .list

    init(makeGraph: @escaping () -> CharactersScreenGraph,
         makeSection: @escaping (CharactersScreenGraph, CharactersLayout) -> Content) {
        _graph = StateObject(wrappedValue: Owned(makeGraph))
        self.makeSection = makeSection
    }

    var body: some View {
        NavigationStack {
            makeSection(graph.value, layout)
                .navigationTitle("Characters")
                .searchable(text: $searchText,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "Search by name")
                // Character names are proper nouns the keyboard has never seen,
                // so autocorrect turns "Squanchy" into a different query and
                // capitalization only adds noise the server ignores.
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: searchText) { _, text in
                    // Debounced inside the view model, not here: the delay is a
                    // property of how the feature spends its request budget, and
                    // a `.task(id:)` on the view would be cancelled by the very
                    // re-render the keystroke causes.
                    graph.value.viewModel.updateSearchText(text)
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
                // A cache wiped behind this screen's back — from the developer
                // tools — is announced through `Storage`, and the screen answers
                // by loading again from scratch. Neither side knows the other
                // exists: the tool does not know this screen, and this screen
                // does not know the tool; the notification is the only thing
                // they share. See `CacheClearedNotification`.
                .onReceive(NotificationCenter.default.publisher(for: .cacheDidClear)) { _ in
                    Task { await graph.value.viewModel.reloadFromScratch() }
                }
        }
        .task {
            await graph.value.viewModel.loadData()
        }
    }
}

#Preview {
    CharactersScreen(
        makeGraph: {
            let useCase = CharactersUseCase(repository: PreviewCharactersRepository())
            let viewModel = CharactersViewModel(charactersUseCase: useCase)
            return CharactersScreenGraph(viewModel: viewModel,
                                         listMapper: CharactersListSectionMapper(viewModel: viewModel),
                                         gridMapper: CharactersGridSectionMapper(viewModel: viewModel),
                                         filterBarMapper: CharactersFilterBarSectionMapper(viewModel: viewModel))
        },
        makeSection: { graph, layout in
            VStack(spacing: 0) {
                CharactersFilterBarSectionView(viewModel: graph.viewModel, mapper: graph.filterBarMapper)
                switch layout {
                case .list:
                    CharactersListSectionView(viewModel: graph.viewModel, mapper: graph.listMapper)
                case .grid:
                    CharactersGridSectionView(viewModel: graph.viewModel, mapper: graph.gridMapper)
                }
            }
        }
    )
}

/// Stubbed at the repository seam rather than the data-source one: the preview
/// wants canned domain models, and standing in for the repository skips the
/// cache, the network and the mapper in one substitution.
///
/// It serves three pages rather than one so the footer, the append and the end
/// of the list are all reachable in the canvas without a network.
///
/// It honours `name` and `status` in memory. That is a *preview* standing in for
/// the server, not the local search the feature deliberately does not do: the
/// point is that the canvas can exercise the search bar, the chips and the empty
/// state at all, which a repository that ignored the filter could not.
private struct PreviewCharactersRepository: CharactersRepositoryContract {
    private static let pageCount = 3
    private static let names = ["Rick Sanchez", "Morty Smith", "Summer Smith",
                                "Beth Smith", "Jerry Smith", "Birdperson"]

    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage {
        let characters = Self.names.enumerated().map { index, name in
            // Ids have to be unique *across* pages: `List` keys rows on them, so
            // a repeated id would collapse page two into page one.
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

}
