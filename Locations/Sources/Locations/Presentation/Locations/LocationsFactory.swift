//
//  LocationsFactory.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import SwiftUI

@MainActor
public enum LocationsFactory {
    /// Returns a screen *description*, not a built graph: the closures below are
    /// only invoked once per screen identity (see `LocationsScreen`), so the
    /// parent re-evaluating its body no longer rebuilds — and throws away — the
    /// view model.
    public static func build(dependencies: any LocationsDependencies) -> some View {
        LocationsScreen(
            makeGraph: { makeGraph(dependencies: dependencies) },
            makeSection: { graph in section(graph) }
        )
    }

    /// Drops every page this feature has cached.
    ///
    /// On the factory rather than exposed as a data source, because the cache
    /// namespace is the feature's own private business: a developer-tools screen
    /// gets to say "clear Locations" without learning the string, and no caller
    /// outside this module can reach a namespace that is not theirs.
    public static func purgeCache(dependencies: any LocationsDependencies) async throws {
        try await LocationsLocalDataSource(cacheStore: dependencies.cacheStore).removeAll()
    }

    /// The feature's composition root: every layer is wired here by constructor
    /// injection, from the infrastructure the app provides down to the screen.
    static func makeGraph(dependencies: any LocationsDependencies) -> LocationsScreenGraph {
        let remoteDataSource = LocationsRemoteDataSource(client: dependencies.graphQLClient)
        let localDataSource = LocationsLocalDataSource(cacheStore: dependencies.cacheStore)
        let repository = LocationsRepository(remoteDataSource: remoteDataSource,
                                             localDataSource: localDataSource,
                                             mapper: LocationEntityMapper())
        return makeGraph(repository: repository)
    }

    /// The half of the wiring below the repository. Split out so a preview — or
    /// a test — can substitute the one seam that reaches the network without
    /// re-stating the three objects above it.
    static func makeGraph(repository: LocationsRepositoryContract) -> LocationsScreenGraph {
        let useCase = LocationsUseCase(repository: repository)
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        return LocationsScreenGraph(viewModel: viewModel,
                                    carouselMapper: LocationsCarouselSectionMapper(viewModel: viewModel),
                                    detailMapper: LocationDetailSectionMapper(viewModel: viewModel))
    }

    /// The whole screen on a repository of the caller's choosing, for the canvas.
    static func previewScreen(repository: LocationsRepositoryContract) -> some View {
        LocationsScreen(makeGraph: { makeGraph(repository: repository) },
                        makeSection: { graph in section(graph) })
    }

    /// The two sections, stacked.
    ///
    /// No `GeometryReader` and no fraction: the carousel has an intrinsic height
    /// — one row of circles and a footer — so it can simply be asked for it, and
    /// the card takes everything left over. That is the difference from the
    /// helix this replaced, which filled whatever it was given and so needed a
    /// number naming how much that was. Composed here rather than inside either
    /// section, the same place the characters screen composes its filter bar over
    /// its list: the sections describe *what* they draw and the composition
    /// decides how much room each one gets.
    @ViewBuilder
    private static func section(_ graph: LocationsScreenGraph) -> some View {
        VStack(spacing: 0) {
            LocationsCarouselSectionView(viewModel: graph.viewModel, mapper: graph.carouselMapper)
            LocationDetailSectionView(mapper: graph.detailMapper)
//                .frame(maxHeight: .infinity)
        }
    }
}
