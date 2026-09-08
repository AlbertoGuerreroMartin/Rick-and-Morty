//
//  LocationsViewModel.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine
import Foundation

/// The screen's state, as five independent published facts.
///
/// It conforms to *both* section contracts. The carousel and the detail card
/// below it are two views of the same two things — the locations that were
/// loaded and which of them is focused — so a second view model would be a
/// second copy of the selection, and two copies of a selection are two
/// selections the moment one of them is written.
///
/// **The selection lives here rather than in the carousel.** The obvious place
/// for "which circle is centred" is the view that centres it, and it was not
/// chosen:
/// the detail section needs the same answer, an auto-selection has to happen
/// when a page lands (which the view cannot see), and a reload has to clear it.
/// A published id is what makes all three one fact. It is an *id* and not an
/// index deliberately — an index means something different after every page
/// lands, and the one thing this screen must never do is silently re-point the
/// detail at a different place.
@MainActor
final class LocationsViewModel: LocationsCarouselSectionViewModelContract,
                                LocationDetailSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> {
        $loadingPublished.eraseToAnyPublisher()
    }

    var locationsPublisher: AnyPublisher<[LocationModel]?, Never> {
        $locationsPublished.eraseToAnyPublisher()
    }

    var paginationPublisher: AnyPublisher<LocationsPaginationState, Never> {
        $paginationPublished.eraseToAnyPublisher()
    }

    var loadFailedPublisher: AnyPublisher<Bool, Never> {
        $loadFailedPublished.eraseToAnyPublisher()
    }

    var selectedLocationIdPublisher: AnyPublisher<String?, Never> {
        $selectedLocationIdPublished.eraseToAnyPublisher()
    }

    let locationsUseCase: LocationsUseCaseContract

    init(locationsUseCase: LocationsUseCaseContract) {
        self.locationsUseCase = locationsUseCase
    }

    /// The *initial* load and every reload. Later pages have their own state
    /// below, so that appending page 5 never blanks the carousel the user is
    /// looking at.
    @Published var loadingPublished = false
    /// Every location loaded so far, across all pages, in arrival order — which
    /// is also the order they are laid out along the carousel.
    @Published var locationsPublished: [LocationModel]?
    /// Starts at `.end` — before the first page lands there is provably nothing
    /// *more* to load, and that keeps the footer out of the way until
    /// `loadData()` has seen an `info.next`.
    @Published var paginationPublished: LocationsPaginationState = .end
    /// Whether the last (re)load of page 1 failed.
    @Published var loadFailedPublished = false
    /// The location the carousel is focused on, and the one the card below
    /// describes. `nil` until the first page lands.
    @Published var selectedLocationIdPublished: String?

    private var hasLoaded = false
    private var isFetching = false

    /// Bumped at the start of every reload; a fetch publishes only while its own
    /// generation is still the current one.
    ///
    /// Cancelling the previous reload task is not enough on its own. A request
    /// that has already left the device cannot be un-sent, and nothing about
    /// `Task.cancel()` guarantees the work stops at a convenient point. The
    /// counter is what makes a late answer harmless rather than a carousel that
    /// grows a second copy of page 2.
    private var generation = 0

    /// The in-flight *next page* request, owned by the view model rather than by
    /// the caller. See `loadNextPage()`.
    private var nextPageTask: Task<Void, Never>?

    /// The in-flight page-1 (re)load. Internal, not private, only so tests can
    /// await it: a reload is started from synchronous UI callbacks, so there is
    /// otherwise nothing for a test to wait on but a sleep.
    private(set) var reloadTask: Task<Void, Never>?

    func loadData() async {
        // `.task` is bound to the view's appear/disappear lifetime, so it fires
        // again on every return to the tab. Only the first one does any work.
        guard !hasLoaded, !isFetching else { return }

        isFetching = true
        defer { isFetching = false }

        await startReload().value
    }

    /// Re-asks for page 1 — the Retry button of the failed empty state.
    func retryLoad() {
        startReload()
    }

    /// Throws away what is on screen and loads the carousel again from page 1.
    ///
    /// The screen calls this when a cache has been cleared behind its back — see
    /// `CacheClearedNotification`. A cleared cache is invisible on its own, so
    /// the reload is what makes it observable: the next request has to leave the
    /// device, and the API logger shows it doing so. Everything in flight is
    /// cancelled and the page task awaited first, so its rows cannot land on top
    /// of the fresh first page.
    ///
    /// The selection is cleared rather than kept. Unlike the characters screen's
    /// search text — which is something the *user* typed and would notice
    /// losing — the focus is a position in a carousel that is about to be
    /// rebuilt from nothing, and holding an id that may not come back in the new
    /// page 1
    /// would leave the card below describing a place that is no longer on the
    /// wire. Page 1 landing re-selects its first location, exactly as on a cold
    /// start.
    func reloadFromScratch() async {
        reloadTask?.cancel()
        if let task = nextPageTask {
            task.cancel()
            await task.value
        }

        hasLoaded = false
        locationsPublished = nil
        paginationPublished = .end
        selectedLocationIdPublished = nil
        await startReload().value
    }

    // MARK: - Selection

    /// Focuses a location: the circle that settled at the centre of the
    /// carousel, or the first one of a page that just landed.
    ///
    /// Two no-ops, both of which matter. Re-selecting what is already selected
    /// would wake every subscriber to redraw the same card — and the carousel
    /// reports a focus at the end of *every* scroll, including one that came
    /// back where it started. And an id this view model does not hold is
    /// refused rather than published: the detail resolves the id against the
    /// same list, so publishing one that is not in it would hide the card with
    /// no way for the user to tell why.
    func selectLocation(id: String) {
        guard id != selectedLocationIdPublished,
              locationsPublished?.contains(where: { $0.id == id }) == true else { return }
        selectedLocationIdPublished = id
    }

    // MARK: - Loading

    /// Every load — the first one, a retry, a cache clear — goes through here and
    /// is handled identically: the carousel hides behind the spinner, page 1 is
    /// fetched, and the answer replaces the circles.
    @discardableResult
    private func startReload() -> Task<Void, Never> {
        // A superseded reload's answer is worthless — unlike a next page, it is
        // not kept for later — so cancelling it is the right trade even against
        // the rate limit.
        reloadTask?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await reload()
        }
        reloadTask = task
        return task
    }

    private func reload() async {
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

        loadingPublished = true
        // No footer while the answer is unknown: the old `nextPage` belongs to
        // the list that is being thrown away.
        paginationPublished = .end

        do {
            let page = try await locationsUseCase.fetchLocations(page: 1)
            guard reloadGeneration == generation else { return }
            locationsPublished = page.locations
            paginationPublished = LocationsPaginationState(nextPage: page.nextPage)
            // The carousel always has a circle at its centre, so the screen
            // would otherwise open on a card describing nothing while a location
            // sits focused in front of the user. Selecting the first one is what
            // makes "whatever is at the focus is selected" true from the first
            // frame rather than from the first gesture.
            selectedLocationIdPublished = page.locations.first?.id
            loadFailedPublished = false
            hasLoaded = true
            loadingPublished = false
        } catch {
            // A cancelled reload owns nothing: the newer one is already driving
            // the state, and writing an empty list here would blank its result.
            guard reloadGeneration == generation,
                  !Task.isCancelled,
                  !(error is CancellationError) else { return }
            locationsPublished = []
            paginationPublished = .end
            selectedLocationIdPublished = nil
            loadFailedPublished = true
            loadingPublished = false
        }
    }

    // MARK: - Pagination

    /// Loads the page the pagination state is pointing at, if any.
    ///
    /// The awaited work lives in a `Task` the *view model* owns, and the caller
    /// only awaits its value. That indirection is the point: the trigger here is
    /// a focus that settled near the end of the carousel, and the `.task`
    /// carrying it is cancelled by the very next flick. Cancelling a request that has
    /// already left the device buys nothing and costs a lot —
    /// rickandmortyapi answers **429** to a client that asks too often, so the
    /// abandoned request still counts against the budget while its response is
    /// thrown away. Owning the task means a fast scroll costs one request that
    /// is actually kept.
    ///
    /// Only one page is ever in flight; a second caller (a re-fired `.task`, the
    /// retry button, a focus that settled twice) joins the existing task instead
    /// of starting a new one.
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

        let requestGeneration = generation

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.nextPageTask = nil }

            do {
                let result = try await locationsUseCase.fetchLocations(page: page)
                // A reload started while this page was in flight. Its rows are
                // answers to a question nobody is asking any more.
                guard requestGeneration == self.generation else { return }
                locationsPublished = (locationsPublished ?? []) + result.locations
                paginationPublished = LocationsPaginationState(nextPage: result.nextPage)
            } catch {
                guard requestGeneration == self.generation else { return }
                // Cancellation is not a failure, so it must not land the user on
                // a retry footer. Back to `.idle` on the same page: the focus
                // settling near the end again simply asks for it once more.
                //
                // Both halves are checked, exactly as `reload()` does. This task
                // being cancelled is one way to get here; the other is a
                // `CancellationError` thrown *underneath* it — the repository's
                // policy rethrows one rather than answering from a stale entry —
                // and only the error says so.
                guard !Task.isCancelled, !(error is CancellationError) else {
                    paginationPublished = .idle(nextPage: page)
                    return
                }
                // Everything already on the carousel stays there. Only the footer
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
