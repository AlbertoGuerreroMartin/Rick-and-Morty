//
//  CharacterDetailFactory.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Core
import Storage
import SwiftUI

/// Composes the detail screen from the scope; the registrations live in `CharactersAssembly`.
@MainActor
enum CharacterDetailFactory {
    static func build(root: DependencyContainer, id: String) -> some View {
        CharacterDetailScreen(
            makeScope: {
                let scope = root.makeChild()
                // The route's id as a scope value; the view model factory reads it.
                scope.register(CharacterDetailContext.self) { _ in CharacterDetailContext(id: id) }
                return scope
            },
            makeSections: { scope in
                CharacterDetailHeaderSectionView(
                    viewModel: scope.resolve((any CharacterDetailHeaderSectionViewModelContract).self),
                    renderModelPublisher: scope.resolve(CharacterDetailHeaderSectionMapper.self).renderModelPublisher()
                )
                CharacterDetailInfoSectionView(
                    viewModel: scope.resolve((any CharacterDetailInfoSectionViewModelContract).self),
                    renderModelPublisher: scope.resolve(CharacterDetailInfoSectionMapper.self).renderModelPublisher()
                )
                CharacterDetailEpisodesSectionView(
                    viewModel: scope.resolve((any CharacterDetailEpisodesSectionViewModelContract).self),
                    renderModelPublisher: scope.resolve(CharacterDetailEpisodesSectionMapper.self).renderModelPublisher()
                )
            }
        )
    }
}
