//
//  EpisodesAssembly.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Core

/// The feature's composition root: every collaborator registered by contract into the app's root
/// container once at launch. Nothing else calls an initializer.
@MainActor
public enum EpisodesAssembly {
    public static func register(in root: DependencyContainer,
                                dependencies: any EpisodesDependencies,
                                navigator: EpisodesNavigator) {
        // App-level objects are read off `dependencies`, not registered: the root is shared by every feature.
        root.register((any EpisodesLocalDataSourceContract).self) { _ in
            EpisodesLocalDataSource(cacheStore: dependencies.cacheStore)
        }
        root.register((any EpisodesRemoteDataSourceContract).self) { _ in
            EpisodesRemoteDataSource(client: dependencies.graphQLClient)
        }
        root.register((any HBOMaxLinksRemoteDataSourceContract).self) { _ in
            HBOMaxLinksRemoteDataSource(client: dependencies.justWatchClient)
        }
        root.register((any EpisodeEntityMapperContract).self) { _ in EpisodeEntityMapper() }
        root.register((any HBOMaxLinksMapperContract).self) { _ in HBOMaxLinksMapper() }
        root.register((any EpisodesRepositoryContract).self) {
            EpisodesRepository(remoteDataSource: $0.resolve((any EpisodesRemoteDataSourceContract).self),
                               hboMaxLinksRemoteDataSource: $0.resolve((any HBOMaxLinksRemoteDataSourceContract).self),
                               localDataSource: $0.resolve((any EpisodesLocalDataSourceContract).self),
                               mapper: $0.resolve((any EpisodeEntityMapperContract).self),
                               linksMapper: $0.resolve((any HBOMaxLinksMapperContract).self))
        }
        root.register((any EpisodesUseCaseContract).self) {
            EpisodesUseCase(repository: $0.resolve((any EpisodesRepositoryContract).self))
        }
        root.register(EpisodesNavigator.self) { _ in navigator }
        root.register((any EpisodesViewModelContract).self, lifetime: .scoped) {
            EpisodesViewModel(episodesUseCase: $0.resolve((any EpisodesUseCaseContract).self))
        }
        // Alias onto the one view model: the section resolves its contract, never the concrete type.
        root.register((any EpisodesListSectionViewModelContract).self, lifetime: .scoped) {
            $0.resolve((any EpisodesViewModelContract).self)
        }
        root.register((any EpisodesListSectionMapperContract).self, lifetime: .scoped) {
            EpisodesListSectionMapper(viewModel: $0.resolve((any EpisodesListSectionViewModelContract).self))
        }
    }
}
