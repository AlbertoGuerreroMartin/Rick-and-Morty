//
//  LocationsFactory.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import SwiftUI

@MainActor
public enum LocationsFactory {
    /// Returns a screen description, not a built graph: the closures are invoked once per
    /// screen identity, so a parent re-evaluating its body doesn't rebuild the view model.
    public static func build(dependencies: any LocationsDependencies) -> some View {
        LocationsScreen(
            makeGraph: { makeGraph(dependencies: dependencies) },
            makeSection: { graph in section(graph) }
        )
    }

    /// On the factory, not exposed as a data source: the cache namespace stays private to this module.
    public static func purgeCache(dependencies: any LocationsDependencies) async throws {
        try await LocationsLocalDataSource(cacheStore: dependencies.cacheStore).removeAll()
    }

    static func makeGraph(dependencies: any LocationsDependencies) -> LocationsScreenGraph {
        let remoteDataSource = LocationsRemoteDataSource(client: dependencies.graphQLClient)
        let localDataSource = LocationsLocalDataSource(cacheStore: dependencies.cacheStore)
        let repository = LocationsRepository(remoteDataSource: remoteDataSource,
                                             localDataSource: localDataSource,
                                             mapper: LocationEntityMapper())
        return makeGraph(repository: repository)
    }

    /// Split out so a preview or test can substitute the repository without restating the wiring above it.
    static func makeGraph(repository: LocationsRepositoryContract) -> LocationsScreenGraph {
        let useCase = LocationsUseCase(repository: repository)
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        return LocationsScreenGraph(viewModel: viewModel,
                                    carouselMapper: LocationsCarouselSectionMapper(viewModel: viewModel),
                                    detailMapper: LocationDetailSectionMapper(viewModel: viewModel))
    }

    static func previewScreen(repository: LocationsRepositoryContract) -> some View {
        LocationsScreen(makeGraph: { makeGraph(repository: repository) },
                        makeSection: { graph in section(graph) })
    }

    /// Carousel has an intrinsic height; the detail card takes the remaining space.
    @ViewBuilder
    private static func section(_ graph: LocationsScreenGraph) -> some View {
        VStack(spacing: 0) {
            LocationsCarouselSectionView(viewModel: graph.viewModel, mapper: graph.carouselMapper)
            LocationDetailSectionView(mapper: graph.detailMapper)
        }
    }
}
