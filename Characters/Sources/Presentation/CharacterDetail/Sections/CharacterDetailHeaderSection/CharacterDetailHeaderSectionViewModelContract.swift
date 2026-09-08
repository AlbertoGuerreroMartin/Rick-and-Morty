//
//  CharacterDetailHeaderSectionViewModelContract.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine

/// What the header needs from the view model.
///
/// It is the only one of the three sections that asks for `loadFailedPublisher`
/// or offers a `retryLoad`, and that is the whole point of splitting the screen
/// this way: the header owns the spinner and the failure, so the info card and
/// the episode list never have to describe a state in which there is nothing to
/// draw. They simply are not there.
///
/// Main-actor isolated: the conforming view models, the mapper and the section
/// views all live on the main actor, and `@Published` projected values can only
/// be read from the view model's own isolation domain.
@MainActor
protocol CharacterDetailHeaderSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }

    /// The character, or `nil` when no load has ever landed — which is not the
    /// same as a failure and must not draw an error.
    var detailPublisher: AnyPublisher<CharacterDetailModel?, Never> { get }

    /// Whether the last load failed. The header is the section that says so,
    /// because it is the one that occupies the screen while there is nothing
    /// else on it.
    var loadFailedPublisher: AnyPublisher<Bool, Never> { get }

    /// Re-asks for the character. Drives the Retry button of the failed state.
    func retryLoad()
}
