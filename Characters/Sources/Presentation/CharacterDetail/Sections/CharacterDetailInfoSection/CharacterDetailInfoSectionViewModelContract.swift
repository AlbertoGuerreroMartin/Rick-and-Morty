//
//  CharacterDetailInfoSectionViewModelContract.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine

/// What the info card needs from the view model: the character, and whether a
/// load is running.
///
/// Deliberately narrower than the header's. This section has no failure state
/// and no button — the header owns both — so asking for `loadFailedPublisher`
/// here would be declaring a dependency on something it cannot act on, and the
/// compiler would stop noticing if that ever changed.
///
/// Main-actor isolated: the conforming view models, the mapper and the section
/// views all live on the main actor, and `@Published` projected values can only
/// be read from the view model's own isolation domain.
@MainActor
protocol CharacterDetailInfoSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }

    /// The character, or `nil` when no load has ever landed.
    var detailPublisher: AnyPublisher<CharacterDetailModel?, Never> { get }
}
