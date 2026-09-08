//
//  CharacterDetailInfoSectionViewModelContract.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine

/// What the info card needs from the view model. Narrower than the header's: no failure state, that's the header's.
@MainActor
protocol CharacterDetailInfoSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }

    /// The character, or `nil` when no load has landed.
    var detailPublisher: AnyPublisher<CharacterDetailModel?, Never> { get }
}
