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
    public static func build(dependencies: any LocationsDependencies,
                             navigator: LocationsNavigator,
                             external: some LocationsExternalDestinations) -> some View {
        LocationsScreen(
            makeGraph: { makeGraph(dependencies: dependencies, navigator: navigator) },
            makeSection: { graph in section(graph) },
            // Exhaustive switch: adding a `LocationsRoute` case is a compile error here.
            makeDestination: { route in
                switch route {
                case .character(let id):
                    external.characterDetail(id: id)
                }
            }
        )
    }

    /// On the factory, not exposed as a data source: the cache namespace stays private to this module.
    public static func purgeCache(dependencies: any LocationsDependencies) async throws {
        try await LocationsLocalDataSource(cacheStore: dependencies.cacheStore).removeAll()
    }

    static func makeGraph(dependencies: any LocationsDependencies,
                          navigator: LocationsNavigator) -> LocationsScreenGraph {
        let remoteDataSource = LocationsRemoteDataSource(client: dependencies.graphQLClient)
        let localDataSource = LocationsLocalDataSource(cacheStore: dependencies.cacheStore)
        let repository = LocationsRepository(remoteDataSource: remoteDataSource,
                                             localDataSource: localDataSource,
                                             mapper: LocationEntityMapper())
        return makeGraph(repository: repository, navigator: navigator)
    }

    /// Split out so a preview or test can substitute the repository without restating the wiring above it.
    static func makeGraph(repository: LocationsRepositoryContract,
                          navigator: LocationsNavigator) -> LocationsScreenGraph {
        let useCase = LocationsUseCase(repository: repository)
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        return LocationsScreenGraph(navigator: navigator,
                                    viewModel: viewModel,
                                    carouselMapper: LocationsCarouselSectionMapper(viewModel: viewModel),
                                    detailMapper: LocationDetailSectionMapper(viewModel: viewModel))
    }

    static func previewScreen(repository: LocationsRepositoryContract) -> some View {
        LocationsScreen(makeGraph: { makeGraph(repository: repository, navigator: LocationsNavigator()) },
                        makeSection: { graph in section(graph) },
                        makeDestination: { route in
                            switch route {
                            case .character(let id):
                                Text("Character \(id)")
                            }
                        })
    }

    /// Carousel has an intrinsic height; the detail card takes the remaining space.
    @ViewBuilder
    private static func section(_ graph: LocationsScreenGraph) -> some View {
        VStack(spacing: 0) {
            LocationsCarouselSectionView(
                viewModel: graph.viewModel,
                renderModelPublisher: graph.carouselMapper.renderModelPublisher()
            )
            LocationDetailSectionView(
                viewModel: graph.viewModel,
                renderModelPublisher: graph.detailMapper.renderModelPublisher()
            )
        }
    }
}
