//
//  EpisodesViewModelTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Episodes

/// Every layer takes its collaborator through its initializer, so a test can
/// stand a view model on a stub use case with no container or registry setup.
@Suite("EpisodesViewModel")
@MainActor
struct EpisodesViewModelTests {

    @Test("loadData publishes the catalogue and clears the spinner")
    func loadDataPublishesEpisodes() async {
        let useCase = StubEpisodesUseCase(result: .success(.catalogue))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)

        await viewModel.loadData()

        #expect(viewModel.episodesPublished?.map(\.code) == ["S01E01", "S01E02", "S02E01"])
        #expect(viewModel.loadingPublished == false)
        #expect(viewModel.loadFailedPublished == false)
    }

    @Test("a failed load publishes an empty catalogue and raises the failure flag")
    func loadDataPublishesEmptyOnFailure() async {
        let useCase = StubEpisodesUseCase(result: .failure(StubError()))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)

        await viewModel.loadData()

        #expect(viewModel.episodesPublished?.isEmpty == true)
        #expect(viewModel.loadFailedPublished == true)
        #expect(viewModel.loadingPublished == false)
    }

    /// `.task` re-fires on every return to the tab, and one "load" here is the
    /// whole catalogue — three requests. Re-fetching it per tab visit would be
    /// the single most expensive mistake on this screen.
    @Test("a second loadData does not refetch")
    func loadDataIsIdempotent() async {
        let useCase = StubEpisodesUseCase(result: .success(.catalogue))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)

        await viewModel.loadData()
        await viewModel.loadData()

        #expect(useCase.fetchCallCount == 1)
    }

    /// A load that failed did not land, so the tab coming back is allowed to try
    /// again — the guard is about not re-fetching a catalogue that is already on
    /// screen, not about giving up after one failure.
    @Test("loadData tries again after a failure")
    func loadDataRetriesAfterAFailure() async {
        let useCase = StubEpisodesUseCase(result: .failure(StubError()))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)
        await viewModel.loadData()

        useCase.setResult(.success(.catalogue))
        await viewModel.loadData()

        #expect(useCase.fetchCallCount == 2)
        #expect(viewModel.episodesPublished?.count == 3)
    }

    // MARK: - Search

    /// The search is local, so a keystroke costs one pass through the mapper and
    /// must not spend a request.
    @Test("updateSearchText publishes the query without fetching anything")
    func updateSearchTextDoesNotFetch() async {
        let useCase = StubEpisodesUseCase(result: .success(.catalogue))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)
        await viewModel.loadData()

        viewModel.updateSearchText("pilot")

        #expect(viewModel.searchQueryPublished == EpisodesSearchQuery(text: "pilot"))
        #expect(useCase.fetchCallCount == 1)
    }

    @Test("the published query is normalized")
    func updateSearchTextNormalizes() async {
        let useCase = StubEpisodesUseCase(result: .success(.catalogue))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)

        viewModel.updateSearchText("  pilot  ")
        #expect(viewModel.searchQueryPublished.text == "pilot")

        viewModel.updateSearchText("   ")
        #expect(viewModel.searchQueryPublished == .empty)

        #expect(useCase.fetchCallCount == 0)
    }

    /// Re-typing the same text after trimming is the same query. Republishing it
    /// would wake every subscriber to redo the same filter, group and sort.
    @Test("an unchanged query is not republished")
    func anUnchangedQueryIsANoOp() async {
        let useCase = StubEpisodesUseCase(result: .success(.catalogue))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)

        viewModel.updateSearchText("pilot")
        viewModel.updateSearchText("  pilot  ")

        #expect(viewModel.searchQueryPublished.text == "pilot")
    }

    // MARK: - Retry

    @Test("retryLoad fetches again and clears the failure on success")
    func retryLoadClearsTheFailure() async {
        let useCase = StubEpisodesUseCase(result: .failure(StubError()))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)
        await viewModel.loadData()

        #expect(viewModel.loadFailedPublished == true)

        useCase.setResult(.success(.catalogue))
        viewModel.retryLoad()
        await viewModel.settle()

        #expect(useCase.fetchCallCount == 2)
        #expect(viewModel.loadFailedPublished == false)
        #expect(viewModel.episodesPublished?.count == 3)
        #expect(viewModel.loadingPublished == false)
    }

    /// The search text is a local filter over whatever is loaded, so it survives
    /// a retry the same way it survives a scroll.
    @Test("retrying keeps the search text")
    func retryKeepsTheSearchText() async {
        let useCase = StubEpisodesUseCase(result: .failure(StubError()))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)
        await viewModel.loadData()
        viewModel.updateSearchText("pilot")

        useCase.setResult(.success(.catalogue))
        viewModel.retryLoad()
        await viewModel.settle()

        #expect(viewModel.searchQueryPublished.text == "pilot")
    }

    // MARK: - Purge

    @Test("purgeCache purges and reloads")
    func purgeCachePurgesAndReloads() async {
        let useCase = StubEpisodesUseCase(result: .success(.catalogue))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)
        await viewModel.loadData()

        await viewModel.purgeCache()

        #expect(useCase.purgeCallCount == 1)
        #expect(useCase.fetchCallCount == 2)
        #expect(viewModel.episodesPublished?.count == 3)
        #expect(viewModel.loadingPublished == false)
    }

    /// There is nothing useful to show a developer beyond the console line, and
    /// refusing to reload would leave the button looking broken rather than
    /// merely ineffective.
    @Test("purgeCache still reloads when the purge fails")
    func purgeCacheStillReloadsWhenThePurgeFails() async {
        let useCase = StubEpisodesUseCase(result: .success(.catalogue), purgeError: StubError())
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)
        await viewModel.loadData()

        await viewModel.purgeCache()

        #expect(useCase.purgeCallCount == 1)
        #expect(useCase.fetchCallCount == 2)
        #expect(viewModel.episodesPublished?.count == 3)
    }

    // MARK: - The generation counter

    /// A walk that has already left the device cannot be un-sent, and nothing
    /// about `Task.cancel()` guarantees it stops before it publishes. This is
    /// the race the counter exists for: a stale reload finishing after a newer
    /// one must be a no-op, not a list that flickers back.
    @Test("a stale reload never publishes over a newer one")
    func aStaleReloadNeverPublishes() async {
        let useCase = StubEpisodesUseCase(result: .success(.catalogue))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)
        await viewModel.loadData()

        // The second fetch — the first retry — is held open.
        useCase.hold(call: 2)
        viewModel.retryLoad()
        await useCase.waitUntilCalled(2)
        let staleReload = viewModel.reloadTask

        // A newer reload takes ownership and finishes while the first is still
        // suspended.
        useCase.setResult(.success([.make(name: "Newer", season: 9, number: 9)]))
        viewModel.retryLoad()
        await viewModel.settle()

        #expect(viewModel.episodesPublished?.map(\.name) == ["Newer"])

        // Only now does the stale walk get its answer. It must change nothing.
        useCase.release(call: 2)
        await staleReload?.value

        #expect(viewModel.episodesPublished?.map(\.name) == ["Newer"])
        #expect(viewModel.loadingPublished == false)
    }
}

// MARK: - Test helpers

private extension EpisodesViewModel {
    /// Awaits whatever reload is pending.
    ///
    /// `retryLoad` is synchronous — it is called from SwiftUI actions, which
    /// cannot await — so it leaves its work in a task the view model owns.
    /// Awaiting that task is what makes these tests deterministic instead of
    /// sleep-and-hope.
    func settle() async {
        await reloadTask?.value
    }
}

private struct StubError: Error {}

private extension Array where Element == EpisodeModel {
    /// Three episodes across two seasons: enough for the view model's tests to
    /// assert on identity and order without caring about grouping, which is the
    /// mapper's business.
    static var catalogue: [EpisodeModel] {
        [.make(name: "Pilot", season: 1, number: 1),
         .make(name: "Lawnmower Dog", season: 1, number: 2),
         .make(name: "A Rickle in Time", season: 2, number: 1)]
    }
}

/// A `final class` behind a lock rather than an actor: `EpisodesUseCaseContract`
/// is a synchronous-to-declare, `Sendable` protocol, and an actor could not
/// satisfy it without every call hopping isolation, which would change the very
/// interleaving the generation test is checking.
private final class StubEpisodesUseCase: EpisodesUseCaseContract, @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<[EpisodeModel], StubError>
    private var fetchCount = 0
    private var purgeCount = 0
    /// Fetches that stay suspended until the test releases them, identified by
    /// their ordinal — the view model's requests are otherwise indistinguishable
    /// from one another, and holding *one* of them is the whole point.
    /// Cancellation does not release them on purpose: the test is about what a
    /// *late* answer does, and a fetch that unblocked itself on cancel would
    /// race the assertions.
    private var heldCalls: Set<Int> = []
    private let purgeError: StubError?

    init(result: Result<[EpisodeModel], StubError>, purgeError: StubError? = nil) {
        self.result = result
        self.purgeError = purgeError
    }

    var fetchCallCount: Int { lock.withLock { fetchCount } }
    var purgeCallCount: Int { lock.withLock { purgeCount } }

    func setResult(_ result: Result<[EpisodeModel], StubError>) {
        lock.withLock { self.result = result }
    }

    func hold(call: Int) {
        lock.withLock { _ = heldCalls.insert(call) }
    }

    func release(call: Int) {
        lock.withLock { _ = heldCalls.remove(call) }
    }

    /// Suspends until `count` fetches have been made. Bounded, so a test that
    /// never gets its call fails on its assertions rather than hanging the suite.
    func waitUntilCalled(_ count: Int) async {
        for _ in 0..<100_000 {
            if fetchCallCount >= count { return }
            await Task.yield()
        }
    }

    func fetchEpisodes() async throws -> [EpisodeModel] {
        // The result is snapshotted at call time, so a held fetch answers with
        // what was configured when it *started* rather than with whatever a
        // later test line set up for a newer request.
        let (call, snapshot) = lock.withLock { () -> (Int, Result<[EpisodeModel], StubError>) in
            fetchCount += 1
            return (fetchCount, result)
        }

        while lock.withLock({ heldCalls.contains(call) }) {
            await Task.yield()
        }
        // A suspension point, so a reload really is in flight when the next one
        // starts.
        await Task.yield()
        return try snapshot.get()
    }

    func purgeCache() async throws {
        lock.withLock { purgeCount += 1 }
        if let purgeError { throw purgeError }
    }
}
