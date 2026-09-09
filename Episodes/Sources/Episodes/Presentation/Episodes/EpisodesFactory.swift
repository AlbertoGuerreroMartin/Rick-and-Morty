//
//  EpisodesFactory.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Core
import Storage
import SwiftUI

@MainActor
public enum EpisodesFactory {
    /// Closures below are invoked once per screen identity; see `EpisodesScreen`. The root already
    /// carries every registration; see `EpisodesAssembly`.
    public static func build(root: DependencyContainer,
                             external: some EpisodesExternalDestinations) -> some View {
        EpisodesScreen(
            makeScope: { root.makeChild() },
            makeSection: { scope in
                EpisodesListSectionView(
                    viewModel: scope.resolve((any EpisodesListSectionViewModelContract).self),
                    renderModelPublisher: scope.resolve((any EpisodesListSectionMapperContract).self).renderModelPublisher()
                )
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
    /// No screen scope: the data source is the only collaborator a purge needs.
    public static func purgeCache(root: DependencyContainer) async throws {
        try await root.resolve((any EpisodesLocalDataSourceContract).self).removeAll()
    }
}
