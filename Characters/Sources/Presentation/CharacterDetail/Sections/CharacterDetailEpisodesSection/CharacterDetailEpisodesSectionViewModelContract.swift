//
//  CharacterDetailEpisodesSectionViewModelContract.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine

/// What the episode list needs from the view model.
///
/// The same two streams as the info card, and a separate protocol anyway: each
/// section declares what *it* depends on, so this one can grow — a tap through
/// to an episode, a "show all" — without the card being dragged along. The same
/// reasoning as `CharactersGridSectionViewModelContract`'s.
///
/// Main-actor isolated: the conforming view models, the mapper and the section
/// views all live on the main actor, and `@Published` projected values can only
/// be read from the view model's own isolation domain.
@MainActor
protocol CharacterDetailEpisodesSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }

    /// The character, or `nil` when no load has ever landed. The episodes ride
    /// on it rather than arriving as a stream of their own: they are a property
    /// of the character, and a second publisher would be a second thing that
    /// could disagree with the first.
    var detailPublisher: AnyPublisher<CharacterDetailModel?, Never> { get }
}
