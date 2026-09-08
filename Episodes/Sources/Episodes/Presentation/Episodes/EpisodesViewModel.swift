//
//  EpisodesViewModel.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Foundation

@MainActor
final class EpisodesViewModel: EpisodesListSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> {
        $loadingPublished.eraseToAnyPublisher()
    }

    var episodesPublisher: AnyPublisher<[EpisodeModel]?, Never> {
        $episodesPublished.eraseToAnyPublisher()
    }

    var searchQueryPublisher: AnyPublisher<EpisodesSearchQuery, Never> {
        $searchQueryPublished.eraseToAnyPublisher()
    }

    var loadFailedPublisher: AnyPublisher<Bool, Never> {
        $loadFailedPublished.eraseToAnyPublisher()
    }

    let episodesUseCase: EpisodesUseCaseContract

    init(episodesUseCase: EpisodesUseCaseContract) {
        self.episodesUseCase = episodesUseCase
    }

    @Published var loadingPublished = false
    /// `nil` means no load has ever landed; not the same as "zero episodes" (see the mapper).
    @Published var episodesPublished: [EpisodeModel]?
    @Published var searchQueryPublished: EpisodesSearchQuery = .empty
    @Published var loadFailedPublished = false

    private var hasLoaded = false
    private var isFetching = false

    /// Bumped each reload; a fetch only publishes while its generation is still current, since
    /// cancellation alone can't guarantee an in-flight request stops before delivering.
    private var generation = 0

    /// Internal, not private, so tests can await it: a reload starts from synchronous UI callbacks.
    private(set) var reloadTask: Task<Void, Never>?

    func loadData() async {
        // `.task` refires on every tab return; only the first load does any work.
        guard !hasLoaded, !isFetching else { return }

        isFetching = true
        defer { isFetching = false }

        await startReload().value
    }

    // MARK: - Search

    /// No debounce: the catalogue is already in memory, so a keystroke costs one local match.
    func updateSearchText(_ text: String) {
        let query = EpisodesSearchQuery(text: text)
        guard query != searchQueryPublished else { return }
        searchQueryPublished = query
    }

    func retryLoad() {
        startReload()
    }

    /// Search text is left alone: it's a local filter that survives a reload like it survives a retry.
    func reloadFromScratch() async {
        reloadTask?.cancel()

        hasLoaded = false
        episodesPublished = nil
        await startReload().value
    }

    @discardableResult
    private func startReload() -> Task<Void, Never> {
        reloadTask?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await reload()
        }
        reloadTask = task
        return task
    }

    private func reload() async {
        generation += 1
        let reloadGeneration = generation

        loadingPublished = true

        do {
            let episodes = try await episodesUseCase.fetchEpisodes()
            guard reloadGeneration == generation else { return }
            episodesPublished = episodes
            loadFailedPublished = false
            hasLoaded = true
            loadingPublished = false
        } catch {
            // A cancelled reload owns nothing: the newer one is already driving the state.
            guard reloadGeneration == generation,
                  !Task.isCancelled,
                  !(error is CancellationError) else { return }
            episodesPublished = []
            loadFailedPublished = true
            loadingPublished = false
        }
    }
}
