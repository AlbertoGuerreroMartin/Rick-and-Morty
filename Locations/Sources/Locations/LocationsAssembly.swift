//
//  LocationsAssembly.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Core

/// The feature's composition root: every collaborator registered by contract into the app's root
/// container once at launch. Nothing else calls an initializer.
@MainActor
public enum LocationsAssembly {
    public static func register(in root: DependencyContainer,
                                dependencies: any LocationsDependencies,
                                navigator: LocationsNavigator) {
        // App-level objects are read off `dependencies`, not registered: the root is shared by every feature.
        root.register((any LocationsLocalDataSourceContract).self) { _ in
            LocationsLocalDataSource(cacheStore: dependencies.cacheStore)
        }
        root.register((any LocationsRemoteDataSourceContract).self) { _ in
            LocationsRemoteDataSource(client: dependencies.graphQLClient)
        }
        root.register((any LocationEntityMapperContract).self) { _ in LocationEntityMapper() }
        root.register((any LocationsRepositoryContract).self) {
            LocationsRepository(remoteDataSource: $0.resolve((any LocationsRemoteDataSourceContract).self),
                                localDataSource: $0.resolve((any LocationsLocalDataSourceContract).self),
                                mapper: $0.resolve((any LocationEntityMapperContract).self))
        }
        root.register((any LocationsUseCaseContract).self) {
            LocationsUseCase(repository: $0.resolve((any LocationsRepositoryContract).self))
        }
        root.register(LocationsNavigator.self) { _ in navigator }
        root.register((any LocationsViewModelContract).self, lifetime: .scoped) {
            LocationsViewModel(locationsUseCase: $0.resolve((any LocationsUseCaseContract).self))
        }
        // Aliases onto the one view model, so both sections subscribe to the same publishers.
        root.register((any LocationsCarouselSectionViewModelContract).self, lifetime: .scoped) {
            $0.resolve((any LocationsViewModelContract).self)
        }
        root.register((any LocationDetailSectionViewModelContract).self, lifetime: .scoped) {
            $0.resolve((any LocationsViewModelContract).self)
        }
        root.register(LocationsCarouselSectionMapper.self, lifetime: .scoped) {
            LocationsCarouselSectionMapper(viewModel: $0.resolve((any LocationsCarouselSectionViewModelContract).self))
        }
        root.register(LocationDetailSectionMapper.self, lifetime: .scoped) {
            LocationDetailSectionMapper(viewModel: $0.resolve((any LocationDetailSectionViewModelContract).self))
        }
    }
}
