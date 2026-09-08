//
//  EpisodesListSectionViewModelContract.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine

@MainActor
protocol EpisodesListSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }

    /// `nil` means no load has ever landed, distinct from an empty catalogue.
    var episodesPublisher: AnyPublisher<[EpisodeModel]?, Never> { get }

    var searchQueryPublisher: AnyPublisher<EpisodesSearchQuery, Never> { get }

    var loadFailedPublisher: AnyPublisher<Bool, Never> { get }

    func retryLoad()
}
