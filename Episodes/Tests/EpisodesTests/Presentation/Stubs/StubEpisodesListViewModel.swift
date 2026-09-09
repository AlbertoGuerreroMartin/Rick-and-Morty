//
//  StubEpisodesListViewModel.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Combine
import Foundation
@testable import Episodes

/// Plain stored properties replayed through `Just`, so a test sets a value and gets one emission.
@MainActor
final class StubEpisodesListViewModel: EpisodesListSectionViewModelContract {
    var isLoading = false
    var episodes: [EpisodeModel]?
    var searchQuery: EpisodesSearchQuery = .empty
    var loadFailed = false
    private(set) var retryCallCount = 0

    var loadingPublisher: AnyPublisher<Bool, Never> { Just(isLoading).eraseToAnyPublisher() }
    var episodesPublisher: AnyPublisher<[EpisodeModel]?, Never> { Just(episodes).eraseToAnyPublisher() }
    var searchQueryPublisher: AnyPublisher<EpisodesSearchQuery, Never> {
        Just(searchQuery).eraseToAnyPublisher()
    }
    var loadFailedPublisher: AnyPublisher<Bool, Never> { Just(loadFailed).eraseToAnyPublisher() }

    func retryLoad() {
        retryCallCount += 1
    }
}
