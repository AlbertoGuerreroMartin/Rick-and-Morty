//
//  CharacterDetailHeaderSectionViewModelContract.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine

/// Main-actor isolated: `@Published` projected values can only be read from the view model's own isolation domain.
@MainActor
protocol CharacterDetailHeaderSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }

    var detailPublisher: AnyPublisher<CharacterDetailModel?, Never> { get }

    var loadFailedPublisher: AnyPublisher<Bool, Never> { get }

    func retryLoad()
}
