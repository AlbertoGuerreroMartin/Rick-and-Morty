//
//  CharactersFactory.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import SwiftUI

@MainActor
public enum CharactersFactory {
    /// Returns a screen *description*, not a built graph: the closures below are
    /// only invoked once per screen identity (see `CharactersScreen`), so the
    /// parent re-evaluating its body no longer rebuilds — and throws away — the
    /// view model.
    public static func build(dependencies: any CharactersDependencies) -> some View {
        CharactersScreen(
            makeGraph: { makeGraph(dependencies: dependencies) },
            makeSection: { graph, layout in
                // The bar sits above the results rather than inside them: a
                // section that scrolls away with the rows would take the only
                // way back to the filter sheet with it.
                VStack(spacing: 0) {
                    CharactersFilterBarSectionView(viewModel: graph.viewModel,
                                                   mapper: graph.filterBarMapper)
                    // Two section *types*, not one section with a mode: SwiftUI
                    // tears one down and builds the other, and each subscribes
                    // to its own mapper on appearance, so the new layout shows
                    // the current rows straight away.
                    switch layout {
                    case .list:
                        CharactersListSectionView(viewModel: graph.viewModel, mapper: graph.listMapper)
                    case .grid:
                        CharactersGridSectionView(viewModel: graph.viewModel, mapper: graph.gridMapper)
                    }
                }
            },
            // The detail is built here, when a row is tapped, and not by the
            // sections that name the route: the two layouts push the same value
            // and neither knows what is on the other side of it.
            makeDetail: { route in
                CharacterDetailFactory.build(dependencies: dependencies, route: route)
            }
        )
    }

    /// Drops everything this feature has cached, pages and details alike.
    ///
    /// On the factory rather than exposed as a data source, because the cache
    /// namespace is the feature's own private business: a developer-tools screen
    /// gets to say "clear Characters" without learning the string, and no caller
    /// outside this module can reach a namespace that is not theirs.
    public static func purgeCache(dependencies: any CharactersDependencies) async throws {
        try await CharactersLocalDataSource(cacheStore: dependencies.cacheStore).removeAll()
    }

    /// The feature's composition root: every layer is wired here by constructor
    /// injection, from the infrastructure the app provides down to the screen.
    static func makeGraph(dependencies: any CharactersDependencies) -> CharactersScreenGraph {
        let entityMapper = CharacterEntityMapper()
        let remoteDataSource = CharactersRemoteDataSource(client: dependencies.graphQLClient)
        // The one place the two clients are told apart — here and in
        // `CharacterDetailFactory`. Everything downstream takes a contract, so
        // nothing else in the feature can hand a JustWatch query to
        // rickandmortyapi.
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
        return CharactersScreenGraph(viewModel: viewModel,
                                     listMapper: listMapper,
                                     gridMapper: gridMapper,
                                     filterBarMapper: filterBarMapper)
    }
}
