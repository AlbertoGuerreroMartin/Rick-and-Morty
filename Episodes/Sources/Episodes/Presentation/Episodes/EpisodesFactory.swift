//
//  EpisodesFactory.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import SwiftUI

@MainActor
public enum EpisodesFactory {
    /// Closures below are invoked once per screen identity; see `EpisodesScreen`.
    public static func build(dependencies: any EpisodesDependencies,
                             navigator: EpisodesNavigator,
                             external: some EpisodesExternalDestinations) -> some View {
        EpisodesScreen(
            makeGraph: { makeGraph(dependencies: dependencies, navigator: navigator) },
            makeSection: { graph in
                EpisodesListSectionView(viewModel: graph.viewModel, mapper: graph.listMapper)
            },
            // Exhaustive switch: adding an `EpisodesRoute` case is a compile error here.
            makeDestination: { route in
                switch route {
                case .character(let id):
                    external.characterDetail(id: id)
                }
            }
        )
    }

    /// On the factory, not a data source, so the cache namespace stays private to this feature.
    public static func purgeCache(dependencies: any EpisodesDependencies) async throws {
        try await EpisodesLocalDataSource(cacheStore: dependencies.cacheStore).removeAll()
    }

    static func makeGraph(dependencies: any EpisodesDependencies,
                          navigator: EpisodesNavigator) -> EpisodesScreenGraph {
        let entityMapper = EpisodeEntityMapper()
        let remoteDataSource = EpisodesRemoteDataSource(client: dependencies.graphQLClient)
        let linksRemoteDataSource = HBOMaxLinksRemoteDataSource(client: dependencies.justWatchClient)
        let localDataSource = EpisodesLocalDataSource(cacheStore: dependencies.cacheStore)
        let repository = EpisodesRepository(remoteDataSource: remoteDataSource,
                                            hboMaxLinksRemoteDataSource: linksRemoteDataSource,
                                            localDataSource: localDataSource,
                                            mapper: entityMapper,
                                            linksMapper: HBOMaxLinksMapper())
        let useCase = EpisodesUseCase(repository: repository)
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)
        let listMapper = EpisodesListSectionMapper(viewModel: viewModel)
        return EpisodesScreenGraph(navigator: navigator, viewModel: viewModel, listMapper: listMapper)
    }
}
