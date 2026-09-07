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
            }
        )
    }

    /// The feature's composition root: every layer is wired here by constructor
    /// injection, from the infrastructure the app provides down to the screen.
    static func makeGraph(dependencies: any CharactersDependencies) -> CharactersScreenGraph {
        let entityMapper = CharacterEntityMapper()
        let remoteDataSource = CharactersRemoteDataSource(client: dependencies.graphQLClient)
        let localDataSource = CharactersLocalDataSource(cacheStore: dependencies.cacheStore)
        let repository = CharactersRepository(remoteDataSource: remoteDataSource,
                                              localDataSource: localDataSource,
                                              mapper: entityMapper)
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
