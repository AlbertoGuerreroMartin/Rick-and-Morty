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
        }
        .task {
            await graph.value.viewModel.loadData()
        }
    }
}

#Preview {
    CharactersScreen(
        makeGraph: {
            let repository = CharactersRepository(remoteDataSource: PreviewCharactersRemoteDataSource())
            let useCase = CharactersUseCase(repository: repository)
            let viewModel = CharactersViewModel(charactersUseCase: useCase)
            return CharactersScreenGraph(viewModel: viewModel,
                                         listMapper: CharactersListSectionMapper(viewModel: viewModel))
        },
        makeSection: { graph in
            CharactersListSectionView(mapper: graph.listMapper)
        }
    )
}

private struct PreviewCharactersRemoteDataSource: CharactersRemoteDataSourceContract {
    func fetchCharacters() async throws -> [CharacterModel] {
        ["Rick Sanchez", "Morty Smith", "Summer Smith"].enumerated().map { index, name in
            CharacterModel(id: "\(index)",
                           name: name,
                           status: "Alive",
                           species: "Human",
                           image: nil,
                           origin: nil,
                           location: nil)
        }
    }

    func fetchCharacterDetail(characterId: String) async throws -> CharacterDetailModel {
        CharacterDetailModel(id: characterId,
                             name: "Rick Sanchez",
                             status: nil,
                             species: nil,
                             image: nil,
                             origin: nil,
                             location: nil,
                             episode: [])
    }
}
