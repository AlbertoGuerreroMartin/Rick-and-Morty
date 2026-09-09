//
//  CharactersViewModelTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Foundation
import Testing
@testable import Characters

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

extension CharactersViewModelTests {
    @Test func reloadFromScratchReloadsFromTheFirstPage() async {
        let useCase = StubCharactersUseCase(pages: [
            1: .success(.page(1, nextPage: 2)),
            2: .success(.page(2, nextPage: 3))
        ])
        let viewModel = CharactersViewModel(charactersUseCase: useCase)
        await viewModel.loadData()
        await viewModel.loadNextPage()

        #expect(viewModel.charactersPublished?.count == 4)

        await viewModel.reloadFromScratch()

        #expect(useCase.callCount(for: 1) == 2)
        #expect(viewModel.charactersPublished?.map(\.id) == ["1-0", "1-1"])
        #expect(viewModel.paginationPublished == .idle(nextPage: 2))
        #expect(viewModel.loadingPublished == false)
    }

    @Test func reloadFromScratchKeepsTheAppliedFilterRatherThanTheEmptyOne() async {
        let alive = CharactersFilter(status: .alive)
        let useCase = StubCharactersUseCase(pages: [1: .success(.page(1, nextPage: 2))])
        useCase.setResult(.success(.page(5, nextPage: nil)), for: alive)
        let viewModel = CharactersViewModel(charactersUseCase: useCase, searchDebounce: .zero)
        await viewModel.loadData()

        viewModel.apply(alive)
        await viewModel.settle()
        await viewModel.reloadFromScratch()

        #expect(useCase.calls.last == StubCharactersUseCase.Call(filter: alive, page: 1))
        #expect(viewModel.filterPublished == alive)
        #expect(viewModel.charactersPublished?.map(\.id) == ["5-0", "5-1"])
    }
}

// MARK: - Search and filters

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
        // Trimmed text is the same query as the untrimmed one, so this must not spend a second request.
        viewModel.updateSearchText("  rick  ")
        await viewModel.settle()

        #expect(viewModel.filterPublished == rick)
        #expect(useCase.totalCallCount == 2)
    }

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
        // Filter publishes as soon as the reload starts, not when it answers.
        #expect(viewModel.filterPublished == alive)

        useCase.release(call)
        await viewModel.settle()

        #expect(viewModel.loadingPublished == false)
        #expect(viewModel.charactersPublished?.map(\.id) == ["5-0", "5-1"])
    }

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
        // Let the reload bump the generation and cancel the page task before it is allowed to answer.
        for _ in 0..<20 { await Task.yield() }
        useCase.release(pageTwo)
        await paging.value
        await viewModel.settle()

        #expect(viewModel.charactersPublished?.map(\.id) == ["9-0", "9-1"])
        #expect(viewModel.paginationPublished == .end)
    }

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
    /// Awaits pending page-1 work. Search/filter entry points are synchronous UI callbacks
    /// that leave their work in an owned task, so tests await it instead of sleeping.
    func settle() async {
        await searchDebounceTask?.value
        await reloadTask?.value
    }
}

private extension CharactersPage {
    /// Ids carry the page they came from, so a test can assert on append order, not just counts.
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
