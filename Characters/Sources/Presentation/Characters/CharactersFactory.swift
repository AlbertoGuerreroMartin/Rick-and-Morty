//
//  CharactersFactory.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Core
import Storage
import SwiftUI

@MainActor
public enum CharactersFactory {
    /// Returns a screen description, not a built scope (see `CharactersScreen`). The root already
    /// carries every registration; see `CharactersAssembly`.
    public static func build(root: DependencyContainer) -> some View {
        CharactersScreen(
            makeScope: { root.makeChild() },
            makeSection: { scope, layout in
                // Above the results, not inside them, so it doesn't scroll away with the rows.
                VStack(spacing: 0) {
                    CharactersFilterBarSectionView(
                        viewModel: scope.resolve((any CharactersFilterBarSectionViewModelContract).self),
                        renderModelPublisher: scope.resolve(CharactersFilterBarSectionMapper.self).renderModelPublisher()
                    )
                    // Two section types, not one with a mode, so each subscribes to its own mapper.
                    switch layout {
                    case .list:
                        CharactersListSectionView(
                            viewModel: scope.resolve((any CharactersListSectionViewModelContract).self),
                            renderModelPublisher: scope.resolve(CharactersListSectionMapper.self).renderModelPublisher()
                        )
                    case .grid:
                        CharactersGridSectionView(
                            viewModel: scope.resolve((any CharactersGridSectionViewModelContract).self),
                            renderModelPublisher: scope.resolve(CharactersGridSectionMapper.self).renderModelPublisher()
                        )
                    }
                }
            },
            // Built here, not by the sections that name the route: both layouts push the same
            // value and neither knows what is on the other side of it.
            makeDetail: { id in
                CharacterDetailFactory.build(root: root, id: id)
            }
        )
    }

    /// Character detail as a pushable view with no `NavigationStack` of its own; used by
    /// `Episodes` via `RickMortyExternalNavigator`, since features can't import each other.
    public static func buildCharacterDetail(root: DependencyContainer, id: String) -> some View {
        CharacterDetailFactory.build(root: root, id: id)
    }

    /// Clears everything this feature has cached; kept here so no caller needs the cache namespace.
    /// No screen scope: the data source is the only collaborator a purge needs.
    public static func purgeCache(root: DependencyContainer) async throws {
        try await root.resolve((any CharactersLocalDataSourceContract).self).removeAll()
    }
}
