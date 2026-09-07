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
    /// Every episode in the catalogue. `nil` means no load has ever landed,
    /// which is not the same as "zero episodes" and must not draw an empty
    /// state — the section mapper is where that distinction is spent.
    @Published var episodesPublished: [EpisodeModel]?
    /// What the user is searching for. Published *unfiltered*: the view model's
    /// job is to say what was loaded and what was typed, and the mapper's job is
    /// to turn the pair into rows. Filtering here would mean the view model held
    /// two lists that could disagree.
    @Published var searchQueryPublished: EpisodesSearchQuery = .empty
    /// Whether the last (re)load failed.
    @Published var loadFailedPublished = false

    private var hasLoaded = false
    private var isFetching = false

    /// Bumped at the start of every reload; a fetch publishes only while its own
    /// generation is still the current one.
    ///
    /// Cancelling the previous reload task is not enough on its own. A request
    /// that has already left the device cannot be un-sent, and nothing about
    /// `Task.cancel()` guarantees the work stops at a convenient point — least
    /// of all here, where one "reload" is a walk over three sequential requests.
    /// The counter is what makes a late answer harmless rather than a list that
    /// flickers back to a catalogue nobody is waiting for.
    private var generation = 0

    /// The in-flight (re)load. Internal, not private, only so tests can await
    /// it: a reload is started from synchronous UI callbacks, so there is
    /// otherwise nothing for a test to wait on but a sleep.
    private(set) var reloadTask: Task<Void, Never>?

    func loadData() async {
        // `.task` is bound to the view's appear/disappear lifetime, so it fires
        // again on every return to the tab. Only the first one does any work —
        // and "any work" here is the whole catalogue, so re-fetching it on every
        // tab visit would be the single most expensive mistake on this screen.
        guard !hasLoaded, !isFetching else { return }

        isFetching = true
        defer { isFetching = false }

        await startReload().value
    }

    // MARK: - Search

    /// Records what the user typed. Synchronous, and no debounce.
    ///
    /// The characters screen debounces because every keystroke there is a
    /// request against a rate-limited API. Here the whole catalogue is already
    /// in memory and the search is a substring match over 51 rows, so a
    /// keystroke costs one pass through the mapper and nothing else. A debounce
    /// would buy no requests and cost the user a third of a second of latency on
    /// every character — it would be a delay with nothing on the other side of
    /// the trade.
    func updateSearchText(_ text: String) {
        let query = EpisodesSearchQuery(text: text)
        guard query != searchQueryPublished else { return }
        searchQueryPublished = query
    }

    /// Re-asks for the catalogue — the Retry button of the failed empty state.
    func retryLoad() {
        startReload()
    }

    /// Throws away what is on screen and loads the catalogue again.
    ///
    /// The screen calls this when a cache has been cleared behind its back —
    /// see `CacheClearedNotification`. A cleared cache is invisible on its own,
    /// so the reload is what makes it observable: the next requests have to
    /// leave the device, and the API logger shows them doing so.
    ///
    /// The search text is deliberately left alone: it is a local filter over
    /// whatever is loaded, so it survives the reload the same way it survives a
    /// retry, and clearing it would look like the clear silently discarded what
    /// the user typed.
    func reloadFromScratch() async {
        reloadTask?.cancel()

        hasLoaded = false
        episodesPublished = nil
        await startReload().value
    }

    /// Every load — the first one, a retry, a cache clear — goes through here and is
    /// handled identically: the list hides behind the spinner, the catalogue is
    /// fetched, and the answer replaces the rows.
    @discardableResult
    private func startReload() -> Task<Void, Never> {
        // A superseded reload's answer is worthless, so cancelling it is the
        // right trade even against the rate limit: whatever pages it had already
        // cached are still on disk for the newer walk to pick up.
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
            // A cancelled reload owns nothing: the newer one is already driving
            // the state, and writing an empty list here would blank its result.
            guard reloadGeneration == generation,
                  !Task.isCancelled,
                  !(error is CancellationError) else { return }
            episodesPublished = []
            loadFailedPublished = true
            loadingPublished = false
        }
    }
}
