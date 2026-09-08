//
//  CharactersFactory.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import SwiftUI

@MainActor
public enum CharactersFactory {
    /// Returns a screen description, not a built graph (see `CharactersScreen`). Navigator is
    /// passed in, not built here, because it outlives the screen; see `AppContainer`.
    public static func build(dependencies: any CharactersDependencies,
                             navigator: CharactersNavigator) -> some View {
        CharactersScreen(
            makeGraph: { makeGraph(dependencies: dependencies, navigator: navigator) },
            makeSection: { graph, layout in
                // Above the results, not inside them, so it doesn't scroll away with the rows.
                VStack(spacing: 0) {
                    CharactersFilterBarSectionView(
                        viewModel: graph.viewModel,
                        renderModelPublisher: graph.filterBarMapper.renderModelPublisher()
                    )
                    // Two section types, not one with a mode, so each subscribes to its own mapper.
                    switch layout {
                    case .list:
                        CharactersListSectionView(
                            viewModel: graph.viewModel,
                            renderModelPublisher: graph.listMapper.renderModelPublisher()
                        )
                    case .grid:
                        CharactersGridSectionView(
                            viewModel: graph.viewModel,
                            renderModelPublisher: graph.gridMapper.renderModelPublisher()
                        )
                    }
                }
            },
            // Built here, not by the sections that name the route: both layouts push the same
            // value and neither knows what is on the other side of it.
            makeDetail: { id in
                CharacterDetailFactory.build(dependencies: dependencies, id: id)
            }
        )
    }

    /// Character detail as a pushable view with no `NavigationStack` of its own; used by
    /// `Episodes` via `RickMortyExternalNavigator`, since features can't import each other.
    public static func buildCharacterDetail(dependencies: any CharactersDependencies,
                                            id: String) -> some View {
        CharacterDetailFactory.build(dependencies: dependencies, id: id)
    }

    /// Clears everything this feature has cached; kept here so no caller needs the cache namespace.
    public static func purgeCache(dependencies: any CharactersDependencies) async throws {
        try await CharactersLocalDataSource(cacheStore: dependencies.cacheStore).removeAll()
    }

    /// The feature's composition root.
    static func makeGraph(dependencies: any CharactersDependencies,
                          navigator: CharactersNavigator) -> CharactersScreenGraph {
        let entityMapper = CharacterEntityMapper()
        let remoteDataSource = CharactersRemoteDataSource(client: dependencies.graphQLClient)
        // The one place the two clients are told apart, here and in `CharacterDetailFactory`.
        let linksRemoteDataSource = HBOMaxLinksRemoteDataSource(client: dependencies.justWatchClient)
        let localDataSource = CharactersLocalDataSource(cacheStore: dependencies.cacheStore)
        let repository = CharactersRepository(remoteDataSource: remoteDataSource,
                                              hboMaxLinksRemoteDataSource: linksRemoteDataSource,
                                              localDataSource: localDataSource,
                                              mapper: entityMapper,
                                              detailMapper: CharacterDetailEntityMapper(),
                                              linksMapper: HBOMaxLinksMapper())
        let useCase = CharactersUseCase(repository: repository)
        let viewModel = CharactersViewModel(charactersUseCase: useCase)
        let listMapper = CharactersListSectionMapper(viewModel: viewModel)
        let gridMapper = CharactersGridSectionMapper(viewModel: viewModel)
        let filterBarMapper = CharactersFilterBarSectionMapper(viewModel: viewModel)
        return CharactersScreenGraph(navigator: navigator,
                                     viewModel: viewModel,
                                     listMapper: listMapper,
                                     gridMapper: gridMapper,
                                     filterBarMapper: filterBarMapper)
    }
}
