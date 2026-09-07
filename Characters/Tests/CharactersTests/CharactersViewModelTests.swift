//
//  CharactersViewModelTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Foundation
import Testing
@testable import Characters

/// Every layer takes its collaborator through its initializer, so a test can
/// stand a view model on a stub use case with no container or registry setup.
@MainActor
struct CharactersViewModelTests {
    @Test func loadDataPublishesCharactersFromUseCase() async {
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: nil))])
        let viewModel = CharactersViewModel(charactersUseCase: useCase)

        await viewModel.loadData()

        #expect(viewModel.charactersPublished?.map(\.id) == ["1-0", "1-1"])
        #expect(viewModel.loadingPublished == false)
    }

    @Test func loadDataPublishesEmptyListWhenUseCaseFails() async {
        let useCase = StubCharactersUseCase(pages: [1: .failure(StubError())])
        let viewModel = CharactersViewModel(charactersUseCase: useCase)

        await viewModel.loadData()

        #expect(viewModel.charactersPublished?.isEmpty == true)
        #expect(viewModel.loadingPublished == false)
        #expect(viewModel.paginationPublished == .end)
    }

    @Test func loadDataSeedsPaginationFromTheFirstPage() async {
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: 2))])
        let viewModel = CharactersViewModel(charactersUseCase: useCase)

        await viewModel.loadData()

        #expect(viewModel.paginationPublished == .idle(nextPage: 2))
    }

    @Test func loadDataAsksForTheUnfilteredList() async {
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: nil))])
        let viewModel = CharactersViewModel(charactersUseCase: useCase)

        await viewModel.loadData()

        #expect(useCase.calls == [StubCharactersUseCase.Call(filter: .empty, page: 1)])
        #expect(viewModel.filterPublished == .empty)
    }

    @Test func loadNextPageAppendsInOrderAndAdvancesTheState() async {
        let useCase = StubCharactersUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .success(.page(2, nextPage: 3))
        ])
        let viewModel = CharactersViewModel(charactersUseCase: useCase)

        await viewModel.loadData()
        await viewModel.loadNextPage()

        #expect(viewModel.charactersPublished?.map(\.id) == ["1-0", "1-1", "2-0", "2-1"])
        #expect(viewModel.paginationPublished == .idle(nextPage: 3))
        // The initial spinner belongs to the first load only; appending a page
        // must never blank the rows already on screen.
        #expect(viewModel.loadingPublished == false)
    }

    @Test func loadNextPageEndsTheListWhenThereIsNoNextPage() async {
        let useCase = StubCharactersUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .success(.page(2, nextPage: nil))
        ])
        let viewModel = CharactersViewModel(charactersUseCase: useCase)

        await viewModel.loadData()
        await viewModel.loadNextPage()

        #expect(viewModel.paginationPublished == .end)
    }

    /// The footer's `.task` can fire more than once for the same state (a
    /// re-render, a scroll bounce). Every extra caller must join the in-flight
    /// request rather than spend a second one against a rate-limited API.
    @Test func concurrentLoadNextPageCallsPerformASingleFetch() async {
        let useCase = StubCharactersUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .success(.page(2, nextPage: 3))
        ])
        let viewModel = CharactersViewModel(charactersUseCase: useCase)
        await viewModel.loadData()

        async let first: Void = viewModel.loadNextPage()
        async let second: Void = viewModel.loadNextPage()
        async let third: Void = viewModel.loadNextPage()
        _ = await (first, second, third)

        #expect(useCase.callCount(for: 2) == 1)
        #expect(viewModel.charactersPublished?.map(\.id) == ["1-0", "1-1", "2-0", "2-1"])
    }

    @Test func loadNextPageDoesNothingAtTheEndOfTheList() async {
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: nil))])
        let viewModel = CharactersViewModel(charactersUseCase: useCase)
        await viewModel.loadData()

        #expect(viewModel.paginationPublished == .end)

        await viewModel.loadNextPage()

        #expect(useCase.totalCallCount == 1)
        #expect(viewModel.charactersPublished?.map(\.id) == ["1-0", "1-1"])
        #expect(viewModel.paginationPublished == .end)
    }

    @Test func failedPageKeepsLoadedRowsAndOffersARetry() async {
        let useCase = StubCharactersUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .failure(StubError())
        ])
        let viewModel = CharactersViewModel(charactersUseCase: useCase)

        await viewModel.loadData()
        await viewModel.loadNextPage()

        #expect(viewModel.charactersPublished?.map(\.id) == ["1-0", "1-1"])
        #expect(viewModel.paginationPublished == .failed(nextPage: 2))
    }

    @Test func retryAfterAFailureAsksForTheSamePageAgain() async {
        let useCase = StubCharactersUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .failure(StubError())
        ])
        let viewModel = CharactersViewModel(charactersUseCase: useCase)

        await viewModel.loadData()
        await viewModel.loadNextPage()

        #expect(viewModel.paginationPublished == .failed(nextPage: 2))

        useCase.setResult(.success(.page(2, nextPage: 3)), for: 2)
        await viewModel.loadNextPage()

        #expect(viewModel.charactersPublished?.map(\.id) == ["1-0", "1-1", "2-0", "2-1"])
        #expect(viewModel.paginationPublished == .idle(nextPage: 3))
        #expect(useCase.callCount(for: 2) == 2)
    }
}

/// The purge is a debug affordance, but the reload that follows it is real
/// behaviour with a real race: rows appended by an in-flight page must never
/// land on top of the fresh first page.
extension CharactersViewModelTests {
    @Test func purgeCachePurgesAndReloadsFromTheFirstPage() async {
        let useCase = StubCharactersUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .success(.page(2, nextPage: 3))
        ])
        let viewModel = CharactersViewModel(charactersUseCase: useCase)
        await viewModel.loadData()
        await viewModel.loadNextPage()

        #expect(viewModel.charactersPublished?.count == 4)

        await viewModel.purgeCache()

        #expect(useCase.purgeCallCount == 1)
        #expect(useCase.callCount(for: 1) == 2)
        #expect(viewModel.charactersPublished?.map(\.id) == ["1-0", "1-1"])
        #expect(viewModel.paginationPublished == .idle(nextPage: 2))
        #expect(viewModel.loadingPublished == false)
    }

    @Test func purgeCacheStillReloadsWhenThePurgeFails() async {
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: nil))],
                                            purgeError: StubError())
        let viewModel = CharactersViewModel(charactersUseCase: useCase)
        await viewModel.loadData()

        await viewModel.purgeCache()

        #expect(useCase.callCount(for: 1) == 2)
        #expect(viewModel.charactersPublished?.map(\.id) == ["1-0", "1-1"])
    }

    /// A purge while a search is on screen must come back with the *same*
    /// search, uncached. Reloading `.empty` would look like the purge silently
    /// dropped the user's query.
    @Test func purgeCacheReloadsWithTheAppliedFilterRatherThanTheEmptyOne() async {
        let alive = CharactersFilter(status: .alive)
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: 2))])
        useCase.setResult(.success(.page(5, nextPage: nil)), for: alive)
        let viewModel = CharactersViewModel(charactersUseCase: useCase, searchDebounce: .zero)
        await viewModel.loadData()

        viewModel.apply(alive)
        await viewModel.settle()
        await viewModel.purgeCache()

        #expect(useCase.purgeCallCount == 1)
        #expect(useCase.calls.last == StubCharactersUseCase.Call(filter: alive, page: 1))
        #expect(viewModel.filterPublished == alive)
        #expect(viewModel.charactersPublished?.map(\.id) == ["5-0", "5-1"])
    }
}

// MARK: - Search and filters

/// The feature is server-first: every one of these asserts that the *server* was
/// asked, with the right filter, and that the list on screen is that answer.
extension CharactersViewModelTests {
    @Test func searchTextReplacesTheRowsAndReseedsPagination() async {
        let rick = CharactersFilter(name: "rick")
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: 2))])
        useCase.setResult(.success(.page(7, nextPage: 4)), for: rick)
        let viewModel = CharactersViewModel(charactersUseCase: useCase, searchDebounce: .zero)
        await viewModel.loadData()

        viewModel.updateSearchText("rick")
        await viewModel.settle()

        #expect(viewModel.charactersPublished?.map(\.id) == ["7-0", "7-1"])
        #expect(viewModel.paginationPublished == .idle(nextPage: 4))
        #expect(viewModel.filterPublished == rick)
        #expect(useCase.calls.last == StubCharactersUseCase.Call(filter: rick, page: 1))
    }

    @Test func blankSearchTextNormalizesToNilAndChangesNothing() async {
        let rick = CharactersFilter(name: "rick")
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: nil))])
        useCase.setResult(.success(.page(7, nextPage: nil)), for: rick)
        let viewModel = CharactersViewModel(charactersUseCase: useCase, searchDebounce: .zero)
        await viewModel.loadData()

        viewModel.updateSearchText("   ")
        await viewModel.settle()

        #expect(viewModel.filterPublished == .empty)
        #expect(useCase.totalCallCount == 1)

        viewModel.updateSearchText("rick")
        await viewModel.settle()
        // Re-typing the same text after trimming is the same query, so it must
        // not spend a request against a rate-limited API.
        viewModel.updateSearchText("  rick  ")
        await viewModel.settle()

        #expect(viewModel.filterPublished == rick)
        #expect(useCase.totalCallCount == 2)
    }

    /// A search is a reload like any other: the list hides behind the spinner
    /// until the server answers, and nothing predicted locally stands in for
    /// the answer meanwhile.
    @Test func aSearchHidesTheListBehindTheSpinner() async {
        let rick = CharactersFilter(name: "rick")
        let call = StubCharactersUseCase.Call(filter: rick, page: 1)
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: 2))])
        useCase.setResult(.success(.page(7, nextPage: nil)), for: rick)
        let viewModel = CharactersViewModel(charactersUseCase: useCase, searchDebounce: .zero)
        await viewModel.loadData()

        useCase.hold(call)
        viewModel.updateSearchText("rick")
        await useCase.waitUntilCalled(call)

        #expect(viewModel.loadingPublished == true)
        #expect(viewModel.filterPublished == rick)

        useCase.release(call)
        await viewModel.settle()

        #expect(viewModel.loadingPublished == false)
        #expect(viewModel.charactersPublished?.map(\.id) == ["7-0", "7-1"])
    }

    @Test func aFilterChangeHidesTheListBehindTheSpinner() async {
        let alive = CharactersFilter(status: .alive)
        let call = StubCharactersUseCase.Call(filter: alive, page: 1)
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: 2))])
        useCase.setResult(.success(.page(5, nextPage: nil)), for: alive)
        let viewModel = CharactersViewModel(charactersUseCase: useCase, searchDebounce: .zero)
        await viewModel.loadData()

        useCase.hold(call)
        viewModel.apply(alive)
        await useCase.waitUntilCalled(call)

        #expect(viewModel.loadingPublished == true)
        // The chips update the instant the reload starts, not when it answers.
        #expect(viewModel.filterPublished == alive)

        useCase.release(call)
        await viewModel.settle()

        #expect(viewModel.loadingPublished == false)
        #expect(viewModel.charactersPublished?.map(\.id) == ["5-0", "5-1"])
    }

    /// The expensive race: page 2 of the old query landing on top of page 1 of
    /// the new one.
    @Test func aPageInFlightNeverAppendsToTheReloadedList() async {
        let alive = CharactersFilter(status: .alive)
        let pageTwo = StubCharactersUseCase.Call(filter: .empty, page: 2)
        let useCase = StubCharactersUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .success(.page(2, nextPage: 3))
        ])
        useCase.setResult(.success(.page(9, nextPage: nil)), for: alive)
        let viewModel = CharactersViewModel(charactersUseCase: useCase, searchDebounce: .zero)
        await viewModel.loadData()

        useCase.hold(pageTwo)
        let paging = Task { await viewModel.loadNextPage() }
        await useCase.waitUntilCalled(pageTwo)

        viewModel.apply(alive)
        // Let the reload take ownership before the page is allowed to answer:
        // it bumps the generation, then cancels and awaits the page task, so
        // page 2 resumes into a world that has already moved on.
        for _ in 0..<20 { await Task.yield() }
        useCase.release(pageTwo)
        await paging.value
        await viewModel.settle()

        #expect(viewModel.charactersPublished?.map(\.id) == ["9-0", "9-1"])
        #expect(viewModel.paginationPublished == .end)
    }

    /// The other half of the same race, and the reason for the generation
    /// counter: a request that has already left the device cannot be un-sent, so
    /// a superseded reload has to be *ignored* rather than merely cancelled.
    @Test func aStaleReloadNeverPublishes() async {
        let rick = CharactersFilter(name: "rick")
        let morty = CharactersFilter(name: "morty")
        let heldCall = StubCharactersUseCase.Call(filter: rick, page: 1)
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: nil))])
        useCase.setResult(.success(.page(7, nextPage: 3)), for: rick)
        useCase.setResult(.success(.page(8, nextPage: nil)), for: morty)
        let viewModel = CharactersViewModel(charactersUseCase: useCase, searchDebounce: .zero)
        await viewModel.loadData()

        useCase.hold(heldCall)
        viewModel.updateSearchText("rick")
        await useCase.waitUntilCalled(heldCall)
        let staleReload = viewModel.reloadTask

        viewModel.updateSearchText("morty")
        await viewModel.settle()

        #expect(viewModel.charactersPublished?.map(\.id) == ["8-0", "8-1"])

        useCase.release(heldCall)
        await staleReload?.value

        #expect(viewModel.charactersPublished?.map(\.id) == ["8-0", "8-1"])
        #expect(viewModel.paginationPublished == .end)
        #expect(viewModel.filterPublished == morty)
    }

    /// The search text is not a filter *field*, so nothing that clears fields is
    /// allowed to touch it.
    @Test func clearingFiltersAndApplyingThemAlwaysKeepsTheSearchText() async {
        let rick = CharactersFilter(name: "rick")
        let rickAlive = CharactersFilter(name: "rick", status: .alive)
        let rickAliveHuman = CharactersFilter(name: "rick", status: .alive, species: "Human")
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: nil))])
        useCase.setResult(.success(.page(7, nextPage: nil)), for: rick)
        useCase.setResult(.success(.page(8, nextPage: nil)), for: rickAlive)
        useCase.setResult(.success(.page(9, nextPage: nil)), for: rickAliveHuman)
        let viewModel = CharactersViewModel(charactersUseCase: useCase, searchDebounce: .zero)
        await viewModel.loadData()

        viewModel.updateSearchText("rick")
        await viewModel.settle()

        viewModel.apply(rickAliveHuman)
        await viewModel.settle()
        #expect(viewModel.filterPublished == rickAliveHuman)

        viewModel.clear(.species)
        await viewModel.settle()
        #expect(viewModel.filterPublished == rickAlive)

        viewModel.clearAllFilters()
        await viewModel.settle()
        #expect(viewModel.filterPublished == rick)
        #expect(viewModel.charactersPublished?.map(\.id) == ["7-0", "7-1"])
    }

    @Test func aFailedReloadEmptiesTheListAndRetryAsksAgainWithTheSameFilter() async {
        let alive = CharactersFilter(status: .alive)
        let call = StubCharactersUseCase.Call(filter: alive, page: 1)
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: 2))])
        useCase.setResult(.failure(StubError()), for: alive)
        let viewModel = CharactersViewModel(charactersUseCase: useCase, searchDebounce: .zero)
        await viewModel.loadData()

        viewModel.apply(alive)
        await viewModel.settle()

        #expect(viewModel.charactersPublished?.isEmpty == true)
        #expect(viewModel.loadFailedPublished == true)
        #expect(viewModel.paginationPublished == .end)
        #expect(viewModel.loadingPublished == false)

        useCase.setResult(.success(.page(5, nextPage: nil)), for: alive)
        viewModel.retryLoad()
        await viewModel.settle()

        #expect(viewModel.loadFailedPublished == false)
        #expect(viewModel.charactersPublished?.map(\.id) == ["5-0", "5-1"])
        #expect(useCase.callCount(for: call) == 2)
    }

    /// One request per keystroke would spend eleven of a small budget typing
    /// "Birdperson".
    @Test func rapidKeystrokesCollapseIntoASingleFetch() async {
        let ric = CharactersFilter(name: "ric")
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: nil))])
        useCase.setResult(.success(.page(7, nextPage: nil)), for: ric)
        let viewModel = CharactersViewModel(charactersUseCase: useCase,
                                            searchDebounce: .milliseconds(40))
        await viewModel.loadData()

        viewModel.updateSearchText("r")
        viewModel.updateSearchText("ri")
        viewModel.updateSearchText("ric")
        await viewModel.settle()

        // One for `loadData`, one for the surviving keystroke.
        #expect(useCase.totalCallCount == 2)
        #expect(useCase.calls.last == StubCharactersUseCase.Call(filter: ric, page: 1))
        #expect(viewModel.charactersPublished?.map(\.id) == ["7-0", "7-1"])
    }
}

// MARK: - Test helpers

private extension CharactersViewModel {
    /// Awaits whatever page-1 work is pending.
    ///
    /// The search and filter entry points are synchronous — they are called from
    /// SwiftUI actions, which cannot await — so they leave their work in a task
    /// the view model owns. Awaiting those two tasks is what makes these tests
    /// deterministic instead of sleep-and-hope.
    func settle() async {
        await searchDebounceTask?.value
        await reloadTask?.value
    }
}

private struct StubError: Error {}

private extension CharactersPage {
    /// Two characters whose ids carry the page they came from, so a test can
    /// assert on append *order* and not just on counts.
    static func page(_ page: Int, nextPage: Int?) -> CharactersPage {
        let characters = (0..<2).map { index in
            CharacterModel(id: "\(page)-\(index)",
                           name: "Character \(page)-\(index)",
                           status: .alive,
                           species: "Human",
                           image: URL(string: "https://example.com/\(page)-\(index).jpeg")!,
                           location: CharacterLocation(name: "Citadel of Ricks", dimension: nil))
        }
        return CharactersPage(characters: characters, nextPage: nextPage)
    }
}

/// A `final class` behind a lock rather than an actor: `CharactersUseCaseContract`
/// is a synchronous-to-declare, `Sendable` protocol, and an actor could not
/// satisfy it without every call hopping isolation, which would change the very
/// interleaving these tests are checking.
private final class StubCharactersUseCase: CharactersUseCaseContract, @unchecked Sendable {
    /// One request, as the view model made it. Filter *and* page, because "page
    /// 2" only means anything together with the query it belongs to — which is
    /// exactly what the pagination-versus-reload race is about.
    struct Call: Hashable, Sendable {
        let filter: CharactersFilter
        let page: Int
    }

    private let lock = NSLock()
    private var pagesByNumber: [Int: Result<CharactersPage, StubError>]
    /// Results for a specific filter. They win over `pagesByNumber`, so a test
    /// can say "page 1 of *this* query answers differently" — which is the whole
    /// shape of a search test.
    private var pagesByFilter: [CharactersFilter: Result<CharactersPage, StubError>] = [:]
    private var recorded: [Call] = []
    /// Calls that stay suspended until the test releases them. Cancellation does
    /// not release them on purpose: these tests are about what the view model
    /// does *while* a fetch is open, and a fetch that unblocked itself on cancel
    /// would race the assertions.
    private var heldCalls: Set<Call> = []
    private var purgeCount = 0
    private let purgeError: StubError?

    init(pages: [Int: Result<CharactersPage, StubError>], purgeError: StubError? = nil) {
        self.pagesByNumber = pages
        self.purgeError = purgeError
    }

    var purgeCallCount: Int {
        lock.withLock { purgeCount }
    }

    var calls: [Call] {
        lock.withLock { recorded }
    }

    var totalCallCount: Int {
        lock.withLock { recorded.count }
    }

    func callCount(for page: Int) -> Int {
        lock.withLock { recorded.filter { $0.page == page }.count }
    }

    func callCount(for call: Call) -> Int {
        lock.withLock { recorded.filter { $0 == call }.count }
    }

    func setResult(_ result: Result<CharactersPage, StubError>, for page: Int) {
        lock.withLock { pagesByNumber[page] = result }
    }

    func setResult(_ result: Result<CharactersPage, StubError>, for filter: CharactersFilter) {
        lock.withLock { pagesByFilter[filter] = result }
    }

    func hold(_ call: Call) {
        lock.withLock { _ = heldCalls.insert(call) }
    }

    func release(_ call: Call) {
        lock.withLock { _ = heldCalls.remove(call) }
    }

    /// Suspends until `call` has been made. Bounded, so a test that never gets
    /// its call fails on its assertions rather than hanging the whole suite.
    func waitUntilCalled(_ call: Call) async {
        for _ in 0..<100_000 {
            if callCount(for: call) > 0 { return }
            await Task.yield()
        }
    }

    func purgeCache() async throws {
        lock.withLock { purgeCount += 1 }
        if let purgeError { throw purgeError }
    }

    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage {
        let call = Call(filter: filter, page: page)
        let result = lock.withLock { () -> Result<CharactersPage, StubError> in
            recorded.append(call)
            return pagesByFilter[filter] ?? pagesByNumber[page] ?? .failure(StubError())
        }

        while lock.withLock({ heldCalls.contains(call) }) {
            await Task.yield()
        }
        // A suspension point, so that three callers racing into `loadNextPage()`
        // really are in flight at the same time.
        await Task.yield()
        return try result.get()
    }
}
