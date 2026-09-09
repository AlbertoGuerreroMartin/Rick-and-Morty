//
//  LocationsViewModel.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine
import Foundation

/// The whole screen's view of the view model: every section contract plus what the screen itself calls.
@MainActor
protocol LocationsViewModelContract: LocationsCarouselSectionViewModelContract,
                                     LocationDetailSectionViewModelContract {
    func loadData() async

    func reloadFromScratch() async
}

/// The screen's state, as five published facts. Covers both section contracts since the
/// carousel and detail card share the same locations and selection — a second view model would
/// risk two selections disagreeing. Selection is a published id, not an index: an index means
/// something different after every page lands.
@MainActor
final class LocationsViewModel: LocationsViewModelContract {
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

    @Published var loadingPublished = false
    @Published var locationsPublished: [LocationModel]?
    /// Starts `.end`: nothing more to load until `loadData()` sees an `info.next`.
    @Published var paginationPublished: LocationsPaginationState = .end
    @Published var loadFailedPublished = false
    @Published var selectedLocationIdPublished: String?

    private var hasLoaded = false
    private var isFetching = false

    /// Bumped at the start of every reload; a fetch only publishes while its generation is
    /// still current. Needed because cancelling a task doesn't stop a request already in flight.
    private var generation = 0

    private var nextPageTask: Task<Void, Never>?

    /// Internal, not private, only so tests can await a reload started from a UI callback.
    private(set) var reloadTask: Task<Void, Never>?

    func loadData() async {
        // `.task` re-fires on every return to the tab; only the first one does work.
        guard !hasLoaded, !isFetching else { return }

        isFetching = true
        defer { isFetching = false }

        await startReload().value
    }

    func retryLoad() {
        startReload()
    }

    /// Reloads page 1 from scratch, e.g. after a cache clear (see `CacheClearedNotification`).
    /// Cancels and awaits in-flight work first so it can't land on top of the fresh page.
    /// Selection is cleared, not kept: the carousel is being rebuilt and the old id may not
    /// come back; page 1 landing re-selects its first location, as on a cold start.
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

    /// Ignores a no-op re-selection (the carousel reports focus on every scroll, even one that
    /// returns to start) and an id not in the current list (the detail resolves against it).
    func selectLocation(id: String) {
        guard id != selectedLocationIdPublished,
              locationsPublished?.contains(where: { $0.id == id }) == true else { return }
        selectedLocationIdPublished = id
    }

    // MARK: - Loading

    @discardableResult
    private func startReload() -> Task<Void, Never> {
        // A superseded reload's answer is worthless, so cancelling it is worth the rate-limit cost.
        reloadTask?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await reload()
        }
        reloadTask = task
        return task
    }

    private func reload() async {
        // Bumped before awaiting, so a page that completes mid-wait sees a stale generation.
        generation += 1
        let reloadGeneration = generation

        if let task = nextPageTask {
            task.cancel()
            await task.value
        }
        guard reloadGeneration == generation else { return }

        loadingPublished = true
        paginationPublished = .end

        do {
            let page = try await locationsUseCase.fetchLocations(page: 1)
            guard reloadGeneration == generation else { return }
            locationsPublished = page.locations
            paginationPublished = LocationsPaginationState(nextPage: page.nextPage)
            selectedLocationIdPublished = page.locations.first?.id
            loadFailedPublished = false
            hasLoaded = true
            loadingPublished = false
        } catch {
            // A superseded reload owns nothing: writing here would blank the newer one's result.
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

    /// The task is owned by the view model, not the caller: the trigger (a settling focus) is
    /// cancelled by the next flick, but the request already left the device and would still
    /// count against the API's 429 limit even if abandoned. A second caller joins the existing task.
    func loadNextPage() async {
        guard let task = nextPageTask ?? makeNextPageTask() else { return }
        await task.value
    }

    /// - Returns: `nil` when there's nothing to load (end of list, or a request already running).
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
                // A reload may have started while this page was in flight.
                guard requestGeneration == self.generation else { return }
                locationsPublished = (locationsPublished ?? []) + result.locations
                paginationPublished = LocationsPaginationState(nextPage: result.nextPage)
            } catch {
                guard requestGeneration == self.generation else { return }
                // Cancellation isn't a failure; back to `.idle` so the next focus retries the same page.
                guard !Task.isCancelled, !(error is CancellationError) else {
                    paginationPublished = .idle(nextPage: page)
                    return
                }
                paginationPublished = .failed(nextPage: page)
            }
        }
        nextPageTask = task
        return task
    }
}
