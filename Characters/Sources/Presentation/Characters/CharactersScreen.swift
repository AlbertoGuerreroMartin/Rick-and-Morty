import Core
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
    private let makeSection: (CharactersScreenGraph) -> Content

    init(makeGraph: @escaping () -> CharactersScreenGraph,
         makeSection: @escaping (CharactersScreenGraph) -> Content) {
        _graph = StateObject(wrappedValue: Owned(makeGraph))
        self.makeSection = makeSection
    }

    var body: some View {
        NavigationStack {
            makeSection(graph.value)
                .navigationTitle("Characters")
                .toolbar {
                    // Debug only, and compiled out rather than hidden: a purge
                    // button has no business shipping, and `#if` is the one
                    // guard a release build cannot get wrong.
                    #if DEBUG
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await graph.value.viewModel.purgeCache() }
                        } label: {
                            Label("Purge cache", systemImage: "trash")
                        }
                        .accessibilityIdentifier("characters.purgeCache")
                    }
                    #endif
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
                                         listMapper: CharactersListSectionMapper(viewModel: viewModel))
        },
        makeSection: { graph in
            CharactersListSectionView(viewModel: graph.viewModel, mapper: graph.listMapper)
        }
    )
}

/// Stubbed at the repository seam rather than the data-source one: the preview
/// wants canned domain models, and standing in for the repository skips the
/// cache, the network and the mapper in one substitution.
///
/// It serves three pages rather than one so the footer, the append and the end
/// of the list are all reachable in the canvas without a network.
private struct PreviewCharactersRepository: CharactersRepositoryContract {
    private static let pageCount = 3
    private static let names = ["Rick Sanchez", "Morty Smith", "Summer Smith",
                                "Beth Smith", "Jerry Smith", "Birdperson"]

    func fetchCharacters(page: Int) async throws -> CharactersPage {
        let characters = Self.names.enumerated().map { index, name in
            // Ids have to be unique *across* pages: `List` keys rows on them, so
            // a repeated id would collapse page two into page one.
            let number = (page - 1) * Self.names.count + index + 1
            return CharacterModel(id: "\(number)",
                                  name: "\(name) (page \(page))",
                                  status: .alive,
                                  species: "Human",
                                  image: URL(string: "https://rickandmortyapi.com/api/character/avatar/\(number).jpeg")!,
                                  location: CharacterLocation(name: "C-137", dimension: nil))
        }
        return CharactersPage(characters: characters,
                              nextPage: page < Self.pageCount ? page + 1 : nil)
    }

    func purgeCache() async throws {}
}
