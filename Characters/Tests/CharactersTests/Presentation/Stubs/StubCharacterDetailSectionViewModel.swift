//
//  StubCharacterDetailSectionViewModel.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Combine
import Foundation
@testable import Characters

/// One stub for all three sections: they share one view model on the real screen.
@MainActor
final class StubCharacterDetailSectionViewModel: CharacterDetailHeaderSectionViewModelContract,
                                                 CharacterDetailInfoSectionViewModelContract,
                                                 CharacterDetailEpisodesSectionViewModelContract {
    @Published var isLoading = false
    @Published var detail: CharacterDetailModel?
    @Published var loadFailed = false

    private(set) var retryCallCount = 0

    var loadingPublisher: AnyPublisher<Bool, Never> { $isLoading.eraseToAnyPublisher() }
    var detailPublisher: AnyPublisher<CharacterDetailModel?, Never> { $detail.eraseToAnyPublisher() }
    var loadFailedPublisher: AnyPublisher<Bool, Never> { $loadFailed.eraseToAnyPublisher() }

    func retryLoad() {
        retryCallCount += 1
    }
}
