//
//  CharactersViewModel.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine
import Foundation
import Networking

@MainActor
final class CharactersViewModel: CharactersListSectionViewModelContract,
                                 CharactersGridSectionViewModelContract,
                                 CharactersFilterBarSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> {
        $loadingPublished.eraseToAnyPublisher()
    }

    var charactersPublisher: AnyPublisher<[CharacterModel]?, Never> {
        $charactersPublished.eraseToAnyPublisher()
    }

    var paginationPublisher: AnyPublisher<CharactersPaginationState, Never> {
        $paginationPublished.eraseToAnyPublisher()
    }

    var filterPublisher: AnyPublisher<CharactersFilter, Never> {
        $filterPublished.eraseToAnyPublisher()
    }

    var loadFailedPublisher: AnyPublisher<Bool, Never> {
        $loadFailedPublished.eraseToAnyPublisher()
    }

    let charactersUseCase: CharactersUseCaseContract

    /// How long the search bar stays quiet before a keystroke becomes a request.
    ///
    /// Injected rather than hard-coded so tests can collapse it to zero: a
    /// debounce is a timing behaviour, and a test that has to sleep to observe
    /// it is a test that will be flaky on a loaded CI machine.
    private let searchDebounce: Duration

    init(charactersUseCase: CharactersUseCaseContract,
         searchDebounce: Duration = .milliseconds(300)) {
        self.charactersUseCase = charactersUseCase
        self.searchDebounce = searchDebounce
    }

    /// The *initial* load and every filter change. Later pages have their own
    /// state below, so that appending page 5 never blanks the four pages already
    /// on screen.
    @Published var loadingPublished = false
    /// Every character loaded so far, across all pages, in arrival order.
    @Published var charactersPublished: [CharacterModel]?
    /// Starts at `.end` — before the first page lands there is provably nothing
    /// *more* to load, and that keeps the footer out of the way until
    /// `loadData()` has seen an `info.next`.
    @Published var paginationPublished: CharactersPaginationState = .end
    /// The *applied* filter: the rows on screen are its result, always.
    @Published var filterPublished: CharactersFilter = .empty
    /// Whether the last (re)load of page 1 failed.
    @Published var loadFailedPublished = false

    private var hasLoaded = false
    private var isFetching = false

    /// Bumped at the start of every reload; a fetch publishes only while its own
    /// generation is still the current one.
    ///
    /// Cancelling the previous reload task is not enough on its own. A request
    /// that has already left the device cannot be un-sent, and the stub-free
    /// truth is that `URLSession` may well deliver its answer *after* the newer
    /// reload has published: nothing about `Task.cancel()` guarantees the work
    /// stops at a convenient point. The counter is what makes a late answer
    /// harmless rather than a list that flickers back to the previous query.
    private var generation = 0

    /// The in-flight *next page* request, owned by the view model rather than by
    /// the caller. See `loadNextPage()`.
    private var nextPageTask: Task<Void, Never>?

    /// The in-flight page-1 (re)load. Internal, not private, only so tests can
    /// await it: a reload is started from synchronous UI callbacks, so there is
    /// otherwise nothing for a test to wait on but a sleep.
    private(set) var reloadTask: Task<Void, Never>?

    /// The pending debounced search. It awaits the reload it starts, so awaiting
    /// this one covers the whole keystroke-to-rows journey.
    private(set) var searchDebounceTask: Task<Void, Never>?

    func loadData() async {
        // `.task` is bound to the view's appear/disappear lifetime, so it fires
        // again on every return to the tab. Only the first one does any work.
        guard !hasLoaded, !isFetching else { return }

        isFetching = true
        defer { isFetching = false }

        // The applied filter, not `.empty`: on the very first load they are the
        // same value, but going through the one reload path means the initial
        // load can never drift from a reload in how it seeds pagination, clears
        // the failure flag or handles cancellation.
        await startReload(to: filterPublished).value
    }

    // MARK: - Search and filters

    /// Records a keystroke. The request happens `searchDebounce` later, if the
    /// user has stopped typing and the resulting filter is actually different.
    ///
    /// Debouncing is not a nicety here: rickandmortyapi answers **429** to a
    /// client that asks too often, and one request per character of "Birdperson"
    /// is eleven requests for one answer. The cost of the trade is a third of a
    /// second before the spinner appears, which is hardly noticeable while typing.
    func updateSearchText(_ text: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            // `.zero` still suspends, which is what gives a superseded keystroke
            // its chance to notice it was cancelled.
            try? await Task.sleep(for: searchDebounce)
            guard !Task.isCancelled else { return }

            let target = filterPublished.with(name: text)
            guard target != filterPublished else { return }
            await startReload(to: target).value
        }
    }

    /// Applies a whole filter — the sheet's Done button.
    func apply(_ filter: CharactersFilter) {
        guard filter != filterPublished else { return }
        startReload(to: filter)
    }

    /// Drops one constraint — a chip's ×.
    func clear(_ field: CharactersFilter.Field) {
        var filter = filterPublished
        filter.clear(field)
        apply(filter)
    }

    /// Drops the four constraints and keeps the search text.
    func clearAllFilters() {
        apply(filterPublished.clearingFields())
    }

    /// Re-asks for page 1 with the filter already applied — the Retry button of
    /// the failed empty state. Unconditional, unlike `apply`: retrying the same
    /// filter is the entire point.
    func retryLoad() {
        startReload(to: filterPublished)
    }

    /// Throws away what is on screen and loads the list again from page 1.
    ///
    /// The screen calls this when a cache has been cleared behind its back —
    /// see `CacheClearedNotification`. A cleared cache is invisible on its own,
    /// so the reload is what makes it observable: the next request has to
    /// leave the device, and the API logger shows it doing so. Everything in
    /// flight is cancelled and the page task awaited first, so its rows cannot
    /// land on top of the fresh first page.
    ///
    /// The reload uses the **applied** filter rather than `.empty`, so a
    /// developer clearing the cache while looking at a search result gets the
    /// same search back, uncached, instead of silently losing it.
    func reloadFromScratch() async {
        searchDebounceTask?.cancel()
        reloadTask?.cancel()
        if let task = nextPageTask {
            task.cancel()
            await task.value
        }

        hasLoaded = false
        charactersPublished = nil
        paginationPublished = .end
        await startReload(to: filterPublished).value
    }

    /// Every change to the filter — a keystroke, the sheet's Done, a chip's ×,
    /// a retry, a cache clear — goes through here and is handled identically: the list
    /// hides behind the spinner, page 1 of the new filter is fetched, and the
    /// answer replaces the rows. Nothing on screen is ever anything other than
    /// the server's answer to the applied filter, which is the whole point of a
    /// server-first search.
    @discardableResult
    private func startReload(to filter: CharactersFilter) -> Task<Void, Never> {
        // A superseded reload's answer is worthless — unlike a next page, it is
        // not kept for later — so cancelling it is the right trade even against
        // the rate limit.
        reloadTask?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await reload(to: filter)
        }
        reloadTask = task
        return task
    }

    private func reload(to filter: CharactersFilter) async {
        // Bumped *before* awaiting the page below, so a page that completes
        // while we wait for it already sees a stale generation and drops its
        // rows instead of appending them to a list that is about to be replaced.
        generation += 1
        let reloadGeneration = generation

        if let task = nextPageTask {
            task.cancel()
            await task.value
        }
        // Another reload may have started while we were waiting.
        guard reloadGeneration == generation else { return }

        // The chips update the instant the reload starts, not when it answers.
        filterPublished = filter
        loadingPublished = true
        // No footer while the answer is unknown: the old `nextPage` belongs to
        // the old query and asking for it would append unrelated rows.
        paginationPublished = .end

        do {
            let page = try await charactersUseCase.fetchCharacters(filter: filter, page: 1)
            guard reloadGeneration == generation else { return }
            charactersPublished = page.characters
            paginationPublished = CharactersPaginationState(nextPage: page.nextPage)
            loadFailedPublished = false
            hasLoaded = true
            loadingPublished = false
        } catch {
            // A cancelled reload owns nothing: the newer one is already driving
            // the state, and writing an empty list here would blank its result.
            guard reloadGeneration == generation,
                  !Task.isCancelled,
                  !(error is CancellationError) else { return }
            charactersPublished = []
            paginationPublished = .end
            loadFailedPublished = true
            loadingPublished = false
        }
    }

    // MARK: - Pagination

    /// Loads the page the pagination state is pointing at, if any.
    ///
    /// The awaited work lives in a `Task` the *view model* owns, and the caller
    /// only awaits its value. That indirection is the point: the trigger is a
    /// `.task` on the list's footer row, and SwiftUI cancels it the moment the
    /// row scrolls out of the `List`'s lazy window. Cancelling a request that
    /// has already left the device buys nothing and costs a lot here —
    /// rickandmortyapi answers **429** to a client that asks too often, so the
    /// abandoned request still counts against the budget while its response is
    /// thrown away. Owning the task means a flick past the footer costs one
    /// request that is actually kept.
    ///
    /// Only one page is ever in flight; a second caller (a re-fired `.task`, the
    /// retry button) joins the existing task instead of starting a new one.
    func loadNextPage() async {
        guard let task = nextPageTask ?? makeNextPageTask() else { return }
        // `task` is unstructured, so cancelling *this* caller does not cancel it.
        await task.value
    }

    /// - Returns: the newly started task, or `nil` when there is nothing to load
    ///   (end of the list, or a request already running).
    private func makeNextPageTask() -> Task<Void, Never>? {
        let page: Int
        switch paginationPublished {
        case .idle(let nextPage), .failed(let nextPage):
            page = nextPage
        case .loading, .end:
            return nil
        }

        paginationPublished = .loading

        // Both captured now, not read later: "page 3" only means anything
        // together with the filter it belongs to, and by the time the answer
        // lands `filterPublished` may already describe a different list.
        let filter = filterPublished
        let requestGeneration = generation

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.nextPageTask = nil }

            do {
                let result = try await charactersUseCase.fetchCharacters(filter: filter, page: page)
                // A reload started while this page was in flight. Its rows are
                // answers to a question nobody is asking any more.
                guard requestGeneration == self.generation else { return }
                charactersPublished = (charactersPublished ?? []) + result.characters
                paginationPublished = CharactersPaginationState(nextPage: result.nextPage)
            } catch {
                guard requestGeneration == self.generation else { return }
                // Cancellation is not a failure, so it must not land the user on
                // a retry row. Back to `.idle` on the same page: the footer
                // reappearing asks for it again.
                guard !Task.isCancelled else {
                    paginationPublished = .idle(nextPage: page)
                    return
                }
                // Everything already loaded stays on screen. Only the footer
                // changes, into something the user can tap.
                paginationPublished = .failed(nextPage: page)
            }
        }
        // Assigned before the body can run: we are on the main actor and the
        // task cannot start until this function suspends, which it never does.
        nextPageTask = task
        return task
    }
}
