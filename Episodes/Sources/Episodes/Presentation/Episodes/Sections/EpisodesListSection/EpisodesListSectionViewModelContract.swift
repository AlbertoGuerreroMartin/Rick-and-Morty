//
//  EpisodesListSectionViewModelContract.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine

// Main-actor isolated: the conforming view models, the mapper and the section
// views all live on the main actor, and `@Published` projected values can only
// be read from the view model's own isolation domain.
@MainActor
protocol EpisodesListSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }

    /// Every episode that was loaded, unfiltered. `nil` means no load has ever
    /// landed — a state the mapper needs to tell apart from an empty catalogue,
    /// because one draws a spinner and the other draws an empty state.
    var episodesPublisher: AnyPublisher<[EpisodeModel]?, Never> { get }

    /// What the user typed. It arrives at the section as a separate stream from
    /// the episodes rather than pre-applied, so the filtering happens once, in
    /// the mapper, where the grouping and ordering already live.
    var searchQueryPublisher: AnyPublisher<EpisodesSearchQuery, Never> { get }

    /// Whether the last load failed. Distinguishes "the search matched nothing"
    /// from "we could not ask", which need different copy and different buttons.
    var loadFailedPublisher: AnyPublisher<Bool, Never> { get }

    /// Re-asks for the catalogue. Drives the Retry button of the failed empty
    /// state.
    func retryLoad()
}
