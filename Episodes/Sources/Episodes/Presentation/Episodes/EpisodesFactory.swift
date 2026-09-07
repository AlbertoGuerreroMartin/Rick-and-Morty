//
//  EpisodesFactory.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import SwiftUI

@MainActor
public enum EpisodesFactory {
    /// Returns a screen *description*, not a built graph: the closures below are
    /// only invoked once per screen identity (see `EpisodesScreen`), so the
    /// parent re-evaluating its body no longer rebuilds — and throws away — the
    /// view model.
    public static func build(dependencies: any EpisodesDependencies) -> some View {
        EpisodesScreen(
            makeGraph: { makeGraph(dependencies: dependencies) },
            makeSection: { graph in
                EpisodesListSectionView(viewModel: graph.viewModel, mapper: graph.listMapper)
            }
        )
    }

    /// The feature's composition root: every layer is wired here by constructor
    /// injection, from the infrastructure the app provides down to the screen.
    static func makeGraph(dependencies: any EpisodesDependencies) -> EpisodesScreenGraph {
        let entityMapper = EpisodeEntityMapper()
        let remoteDataSource = EpisodesRemoteDataSource(client: dependencies.graphQLClient)
        let localDataSource = EpisodesLocalDataSource(cacheStore: dependencies.cacheStore)
        let repository = EpisodesRepository(remoteDataSource: remoteDataSource,
                                            localDataSource: localDataSource,
                                            mapper: entityMapper)
        let useCase = EpisodesUseCase(repository: repository)
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)
        let listMapper = EpisodesListSectionMapper(viewModel: viewModel)
        return EpisodesScreenGraph(viewModel: viewModel, listMapper: listMapper)
    }
}
