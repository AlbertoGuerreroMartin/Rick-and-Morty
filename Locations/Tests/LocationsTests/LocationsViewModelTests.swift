//
//  LocationsViewModelTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation
import Testing
@testable import Locations

/// Every layer takes its collaborator through its initializer, so a test can
/// stand a view model on a stub use case with no container or registry setup.
@Suite("LocationsViewModel")
@MainActor
struct LocationsViewModelTests {

    @Test("loadData publishes the first page and clears the spinner")
    func loadDataPublishesLocations() async {
        let useCase = StubLocationsUseCase(pages: [1: .success(.page(1, nextPage: nil))])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)

        await viewModel.loadData()

        #expect(viewModel.locationsPublished?.map(\.id) == ["1-0", "1-1"])
        #expect(viewModel.loadingPublished == false)
        #expect(viewModel.loadFailedPublished == false)
    }

    @Test("loadData seeds pagination from the first page")
    func loadDataSeedsPagination() async {
        let useCase = StubLocationsUseCase(pages: [1: .success(.page(1, nextPage: 2))])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)

        await viewModel.loadData()

        #expect(viewModel.paginationPublished == .idle(nextPage: 2))
    }

    /// The carousel always has a circle at its centre, so the card below it would
    /// otherwise be blank while a location sits focused in front of the user.
    @Test("the first location of page 1 is selected automatically")
    func loadDataAutoSelectsTheFirstLocation() async {
        let useCase = StubLocationsUseCase(pages: [1: .success(.page(1, nextPage: 2))])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)

        await viewModel.loadData()

        #expect(viewModel.selectedLocationIdPublished == "1-0")
    }

    @Test("a failed load publishes an empty list, no selection and the failure flag")
    func loadDataPublishesEmptyOnFailure() async {
        let useCase = StubLocationsUseCase(pages: [1: .failure(StubError())])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)

        await viewModel.loadData()

        #expect(viewModel.locationsPublished?.isEmpty == true)
        #expect(viewModel.paginationPublished == .end)
        #expect(viewModel.selectedLocationIdPublished == nil)
        #expect(viewModel.loadFailedPublished == true)
        #expect(viewModel.loadingPublished == false)
    }

    /// `.task` re-fires on every return to the tab. Only the first one does any
    /// work — a refetch per tab visit is a request the cache would answer, but
    /// it would also yank the carousel back to the first location.
    @Test("a second loadData does not refetch")
    func loadDataIsIdempotent() async {
        let useCase = StubLocationsUseCase(pages: [1: .success(.page(1, nextPage: nil))])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)

        await viewModel.loadData()
        await viewModel.loadData()

        #expect(useCase.callCount(for: 1) == 1)
    }

    /// A load that failed did not land, so the tab coming back is allowed to try
    /// again — the guard is about not re-fetching a carousel that is already on
    /// screen, not about giving up after one failure.
    @Test("loadData tries again after a failure")
    func loadDataRetriesAfterAFailure() async {
        let useCase = StubLocationsUseCase(pages: [1: .failure(StubError())])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        await viewModel.loadData()

        useCase.setResult(.success(.page(1, nextPage: nil)), for: 1)
        await viewModel.loadData()

        #expect(useCase.callCount(for: 1) == 2)
        #expect(viewModel.locationsPublished?.count == 2)
    }

    @Test("retryLoad fetches again and clears the failure on success")
    func retryLoadClearsTheFailure() async {
        let useCase = StubLocationsUseCase(pages: [1: .failure(StubError())])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        await viewModel.loadData()

        #expect(viewModel.loadFailedPublished == true)

        useCase.setResult(.success(.page(1, nextPage: 2)), for: 1)
        viewModel.retryLoad()
        await viewModel.settle()

        #expect(viewModel.loadFailedPublished == false)
        #expect(viewModel.locationsPublished?.map(\.id) == ["1-0", "1-1"])
        #expect(viewModel.selectedLocationIdPublished == "1-0")
    }

    // MARK: - Pagination

    @Test("the next page is appended in order and the state advances")
    func loadNextPageAppendsInOrder() async {
        let useCase = StubLocationsUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .success(.page(2, nextPage: 3))
        ])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)

        await viewModel.loadData()
        await viewModel.loadNextPage()

        #expect(viewModel.locationsPublished?.map(\.id) == ["1-0", "1-1", "2-0", "2-1"])
        #expect(viewModel.paginationPublished == .idle(nextPage: 3))
        // The initial spinner belongs to the first load only; appending a page
        // must never blank the carousel the user is scrolling.
        #expect(viewModel.loadingPublished == false)
    }

    /// Appending a page must not move the focus. The user is somewhere on the
    /// carousel and a page landing beside them is not a reason to be sent back
    /// to the top.
    @Test("a later page does not change the selection")
    func loadNextPageKeepsTheSelection() async {
        let useCase = StubLocationsUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .success(.page(2, nextPage: nil))
        ])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        await viewModel.loadData()
        viewModel.selectLocation(id: "1-1")

        await viewModel.loadNextPage()

        #expect(viewModel.selectedLocationIdPublished == "1-1")
    }

    @Test("the list ends when there is no next page")
    func loadNextPageEndsTheList() async {
        let useCase = StubLocationsUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .success(.page(2, nextPage: nil))
        ])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)

        await viewModel.loadData()
        await viewModel.loadNextPage()

        #expect(viewModel.paginationPublished == .end)
    }

    /// A focus can settle twice, and the section's `.task(id:)` fires again when
    /// a page lands. Every extra caller must join the request in flight rather
    /// than spend a second one against a rate-limited API.
    @Test("concurrent callers perform a single fetch")
    func concurrentLoadNextPageCallsPerformASingleFetch() async {
        let useCase = StubLocationsUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .success(.page(2, nextPage: 3))
        ])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        await viewModel.loadData()

        async let first: Void = viewModel.loadNextPage()
        async let second: Void = viewModel.loadNextPage()
        async let third: Void = viewModel.loadNextPage()
        _ = await (first, second, third)

        #expect(useCase.callCount(for: 2) == 1)
        #expect(viewModel.locationsPublished?.map(\.id) == ["1-0", "1-1", "2-0", "2-1"])
    }

    @Test("loadNextPage does nothing at the end of the list")
    func loadNextPageDoesNothingAtTheEnd() async {
        let useCase = StubLocationsUseCase(pages: [1: .success(.page(1, nextPage: nil))])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        await viewModel.loadData()

        await viewModel.loadNextPage()

        #expect(useCase.totalCallCount == 1)
        #expect(viewModel.locationsPublished?.map(\.id) == ["1-0", "1-1"])
        #expect(viewModel.paginationPublished == .end)
    }

    @Test("a failed page keeps the loaded circles and offers a retry")
    func failedPageKeepsLoadedRows() async {
        let useCase = StubLocationsUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .failure(StubError())
        ])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)

        await viewModel.loadData()
        await viewModel.loadNextPage()

        #expect(viewModel.locationsPublished?.map(\.id) == ["1-0", "1-1"])
        #expect(viewModel.paginationPublished == .failed(nextPage: 2))
        // The screen did not fail — one page did — so the empty state must not
        // appear under a carousel that has circles on it.
        #expect(viewModel.loadFailedPublished == false)
    }

    /// `.failed` carries the page number precisely so the retry asks for the page
    /// that failed rather than re-deriving it.
    @Test("a retry asks for the same page again")
    func retryAsksForTheSamePage() async {
        let useCase = StubLocationsUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .failure(StubError())
        ])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        await viewModel.loadData()
        await viewModel.loadNextPage()

        useCase.setResult(.success(.page(2, nextPage: 3)), for: 2)
        await viewModel.loadNextPage()

        #expect(viewModel.locationsPublished?.map(\.id) == ["1-0", "1-1", "2-0", "2-1"])
        #expect(viewModel.paginationPublished == .idle(nextPage: 3))
        #expect(useCase.callCount(for: 2) == 2)
    }

    /// Cancellation is not failure: it means a drag moved on, not that the API
    /// refused. Back to `.idle` on the same page, so settling near the end again
    /// simply asks once more instead of showing an error nobody caused.
    @Test("a cancelled page goes back to idle on the same page")
    func cancellationGoesBackToIdle() async {
        let useCase = StubLocationsUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .failure(CancellationError())
        ])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        await viewModel.loadData()

        await viewModel.loadNextPage()

        #expect(viewModel.paginationPublished == .idle(nextPage: 2))
        #expect(viewModel.locationsPublished?.map(\.id) == ["1-0", "1-1"])
    }

    // MARK: - Selection

    @Test("selectLocation publishes a location that is loaded")
    func selectLocationPublishes() async {
        let useCase = StubLocationsUseCase(pages: [1: .success(.page(1, nextPage: nil))])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        await viewModel.loadData()

        viewModel.selectLocation(id: "1-1")

        #expect(viewModel.selectedLocationIdPublished == "1-1")
    }

    /// The detail resolves the id against the same list, so publishing one that
    /// is not in it would hide the card with no way for the user to tell why.
    @Test("an unknown id is ignored")
    func unknownSelectionIsIgnored() async {
        let useCase = StubLocationsUseCase(pages: [1: .success(.page(1, nextPage: nil))])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        await viewModel.loadData()

        viewModel.selectLocation(id: "nowhere")

        #expect(viewModel.selectedLocationIdPublished == "1-0")
    }

    @Test("selecting before anything is loaded is ignored")
    func selectionBeforeLoadingIsIgnored() {
        let useCase = StubLocationsUseCase(pages: [:])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)

        viewModel.selectLocation(id: "1-0")

        #expect(viewModel.selectedLocationIdPublished == nil)
    }

    /// The carousel reports a focus at the end of *every* scroll, including
    /// one that came back where it started. Republishing would wake every
    /// subscriber to redraw the same card.
    @Test("re-selecting what is already selected changes nothing")
    func reselectingIsANoOp() async {
        let useCase = StubLocationsUseCase(pages: [1: .success(.page(1, nextPage: nil))])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        await viewModel.loadData()

        viewModel.selectLocation(id: "1-0")

        #expect(viewModel.selectedLocationIdPublished == "1-0")
    }

    /// A location that arrived with page 2 is selectable exactly like one from
    /// page 1 — the list the id is checked against is the whole carousel.
    @Test("a location from a later page can be selected")
    func aLaterPageIsSelectable() async {
        let useCase = StubLocationsUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .success(.page(2, nextPage: nil))
        ])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        await viewModel.loadData()
        await viewModel.loadNextPage()

        viewModel.selectLocation(id: "2-1")

        #expect(viewModel.selectedLocationIdPublished == "2-1")
    }

    // MARK: - Reload after a cache clear

    @Test("reloadFromScratch reloads from the first page and re-selects")
    func reloadFromScratchReloads() async {
        let useCase = StubLocationsUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .success(.page(2, nextPage: 3))
        ])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        await viewModel.loadData()
        await viewModel.loadNextPage()
        viewModel.selectLocation(id: "2-1")

        #expect(viewModel.locationsPublished?.count == 4)

        await viewModel.reloadFromScratch()

        #expect(useCase.callCount(for: 1) == 2)
        #expect(viewModel.locationsPublished?.map(\.id) == ["1-0", "1-1"])
        #expect(viewModel.paginationPublished == .idle(nextPage: 2))
        // The old focus is gone with the list it belonged to, and the fresh page
        // re-selects its first location exactly as a cold start does.
        #expect(viewModel.selectedLocationIdPublished == "1-0")
        #expect(viewModel.loadingPublished == false)
    }

    /// The expensive race: page 2 of the old list landing on top of page 1 of
    /// the new one.
    @Test("a page in flight never appends to a reloaded list")
    func aPageInFlightNeverAppendsToTheReloadedList() async {
        let useCase = StubLocationsUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .success(.page(2, nextPage: 3))
        ])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        await viewModel.loadData()

        useCase.hold(page: 2)
        let paging = Task { await viewModel.loadNextPage() }
        await useCase.waitUntilCalled(page: 2)

        let reload = Task { await viewModel.reloadFromScratch() }
        // Let the reload bump the generation and start awaiting the page task
        // before that page is allowed to answer, so it resumes into a world that
        // has already moved on.
        for _ in 0..<20 { await Task.yield() }
        useCase.release(page: 2)
        await paging.value
        await reload.value

        #expect(viewModel.locationsPublished?.map(\.id) == ["1-0", "1-1"])
        #expect(viewModel.paginationPublished == .idle(nextPage: 2))
    }

    /// The other half of the same race, and the reason for the generation
    /// counter: a request that has already left the device cannot be un-sent, so
    /// a superseded reload has to be *ignored* rather than merely cancelled.
    @Test("a stale reload never publishes over a newer one")
    func aStaleReloadNeverPublishes() async {
        let useCase = StubLocationsUseCase(pages: [1: .success(.page(1, nextPage: nil))])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        await viewModel.loadData()

        // The second call to page 1 — the first retry — is held open.
        useCase.hold(page: 1, call: 2)
        viewModel.retryLoad()
        await useCase.waitUntilCalled(page: 1, times: 2)
        let staleReload = viewModel.reloadTask

        useCase.setResult(.success(.page(9, nextPage: nil)), for: 1)
        viewModel.retryLoad()
        await viewModel.settle()

        #expect(viewModel.locationsPublished?.map(\.id) == ["9-0", "9-1"])

        useCase.release(page: 1, call: 2)
        await staleReload?.value

        #expect(viewModel.locationsPublished?.map(\.id) == ["9-0", "9-1"])
        #expect(viewModel.selectedLocationIdPublished == "9-0")
        #expect(viewModel.loadingPublished == false)
    }
}

// MARK: - Test helpers

private extension LocationsViewModel {
    /// Awaits whatever page-1 work is pending.
    ///
    /// `retryLoad` is synchronous — it is called from SwiftUI actions, which
    /// cannot await — so it leaves its work in a task the view model owns.
    /// Awaiting that task is what makes these tests deterministic instead of
    /// sleep-and-hope.
    func settle() async {
        await reloadTask?.value
    }
}

struct StubError: Error {}

extension LocationsPage {
    /// Two locations whose ids carry the page they came from, so a test can
    /// assert on append *order* and not just on counts.
    static func page(_ page: Int, nextPage: Int?) -> LocationsPage {
        let locations = (0..<2).map { index in
            LocationModel.make(id: "\(page)-\(index)",
                               name: "Location \(page)-\(index)")
        }
        return LocationsPage(locations: locations, nextPage: nextPage)
    }
}

/// A `final class` behind a lock rather than an actor: `LocationsUseCaseContract`
/// is a synchronous-to-declare, `Sendable` protocol, and an actor could not
/// satisfy it without every call hopping isolation, which would change the very
/// interleaving these tests are checking.
final class StubLocationsUseCase: LocationsUseCaseContract, @unchecked Sendable {
    private let lock = NSLock()
    private var pages: [Int: Result<LocationsPage, any Error>]
    private var recorded: [Int] = []
    /// Calls that stay suspended until the test releases them, identified by the
    /// page *and* how many times that page has been asked for — a retry of page
    /// 1 is the second call, and holding only that one is the whole point.
    /// Cancellation does not release them deliberately: these tests are about
    /// what the view model does while a fetch is open, and a fetch that
    /// unblocked itself on cancel would race the assertions.
    private var heldCalls: Set<Held> = []

    private struct Held: Hashable {
        let page: Int
        let call: Int
    }

    init(pages: [Int: Result<LocationsPage, any Error>]) {
        self.pages = pages
    }

    var totalCallCount: Int { lock.withLock { recorded.count } }

    func callCount(for page: Int) -> Int {
        lock.withLock { recorded.filter { $0 == page }.count }
    }

    func setResult(_ result: Result<LocationsPage, any Error>, for page: Int) {
        lock.withLock { pages[page] = result }
    }

    func hold(page: Int, call: Int = 1) {
        lock.withLock { _ = heldCalls.insert(Held(page: page, call: call)) }
    }

    func release(page: Int, call: Int = 1) {
        lock.withLock { _ = heldCalls.remove(Held(page: page, call: call)) }
    }

    /// Suspends until `page` has been asked for `times` times. Bounded, so a
    /// test that never gets its call fails on its assertions rather than hanging
    /// the whole suite.
    func waitUntilCalled(page: Int, times: Int = 1) async {
        for _ in 0..<100_000 {
            if callCount(for: page) >= times { return }
            await Task.yield()
        }
    }

    func fetchLocations(page: Int) async throws -> LocationsPage {
        // The result is snapshotted at call time, so a held fetch answers with
        // what was configured when it *started* rather than with whatever a
        // later test line set up for a newer request.
        let (call, snapshot) = lock.withLock { () -> (Held, Result<LocationsPage, any Error>) in
            recorded.append(page)
            let call = Held(page: page, call: recorded.filter { $0 == page }.count)
            return (call, pages[page] ?? .failure(StubError()))
        }

        while lock.withLock({ heldCalls.contains(call) }) {
            await Task.yield()
        }
        // A suspension point, so that three callers racing into `loadNextPage()`
        // really are in flight at the same time.
        await Task.yield()
        return try snapshot.get()
    }
}
