//
//  CharacterDetailEpisodesSectionViewModelContract.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine

/// What the episode list needs from the view model. Main-actor isolated, like `@Published`'s projected values.
@MainActor
protocol CharacterDetailEpisodesSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }

    /// The character, or `nil` when no load has landed. Episodes ride on it rather
    /// than a separate stream, so there is only one thing that can disagree.
    var detailPublisher: AnyPublisher<CharacterDetailModel?, Never> { get }
}
