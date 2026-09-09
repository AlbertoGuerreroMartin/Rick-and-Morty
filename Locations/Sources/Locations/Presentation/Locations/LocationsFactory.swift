//
//  LocationsFactory.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Core
import SwiftUI

@MainActor
public enum LocationsFactory {
    /// Returns a screen description, not a built scope: the closures are invoked once per
    /// screen identity, so a parent re-evaluating its body doesn't rebuild the view model.
    public static func build(root: DependencyContainer,
                             external: some LocationsExternalDestinations) -> some View {
        LocationsScreen(
            makeScope: { root.makeChild() },
            makeSection: { scope in section(scope) },
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
    /// No screen scope: the data source is the only collaborator a purge needs.
    public static func purgeCache(root: DependencyContainer) async throws {
        try await root.resolve((any LocationsLocalDataSourceContract).self).removeAll()
    }

    /// Carousel has an intrinsic height; the detail card takes the remaining space.
    @ViewBuilder
    private static func section(_ scope: DependencyContainer) -> some View {
        VStack(spacing: 0) {
            LocationsCarouselSectionView(
                viewModel: scope.resolve((any LocationsCarouselSectionViewModelContract).self),
                renderModelPublisher: scope.resolve((any LocationsCarouselSectionMapperContract).self).renderModelPublisher()
            )
            LocationDetailSectionView(
                viewModel: scope.resolve((any LocationDetailSectionViewModelContract).self),
                renderModelPublisher: scope.resolve((any LocationDetailSectionMapperContract).self).renderModelPublisher()
            )
        }
    }
}
