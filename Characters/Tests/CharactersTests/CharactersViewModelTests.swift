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
    private let lock = NSLock()
    private var pages: [Int: Result<CharactersPage, StubError>]
    private var calls: [Int] = []

    init(pages: [Int: Result<CharactersPage, StubError>]) {
        self.pages = pages
    }

    func setResult(_ result: Result<CharactersPage, StubError>, for page: Int) {
        lock.withLock { pages[page] = result }
    }

    func callCount(for page: Int) -> Int {
        lock.withLock { calls.filter { $0 == page }.count }
    }

    var totalCallCount: Int {
        lock.withLock { calls.count }
    }

    func fetchCharacters(page: Int) async throws -> CharactersPage {
        let result = lock.withLock { () -> Result<CharactersPage, StubError> in
            calls.append(page)
            return pages[page] ?? .failure(StubError())
        }
        // A suspension point, so that three callers racing into `loadNextPage()`
        // really are in flight at the same time.
        await Task.yield()
        return try result.get()
    }
}
