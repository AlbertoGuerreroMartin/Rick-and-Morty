//
//  EpisodesViewModelTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Episodes

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

    @Test("a second loadData does not refetch")
    func loadDataIsIdempotent() async {
        let useCase = StubEpisodesUseCase(result: .success(.catalogue))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)

        await viewModel.loadData()
        await viewModel.loadData()

        #expect(useCase.fetchCallCount == 1)
    }

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

    @Test("the HBO Max link survives the trip to the section")
    func loadDataPublishesTheHBOMaxLink() async {
        let useCase = StubEpisodesUseCase(result: .success([
            .make(name: "Pilot", season: 1, number: 1,
                  hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/1")),
            .make(name: "Lawnmower Dog", season: 1, number: 2)
        ]))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)

        await viewModel.loadData()

        #expect(viewModel.episodesPublished?.map(\.hboMaxURL?.absoluteString)
                == ["https://play.hbomax.com/video/watch/1", nil])
    }

    // MARK: - Search

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

    // MARK: - Reload after a cache clear

    @Test("reloadFromScratch fetches the catalogue again")
    func reloadFromScratchFetchesAgain() async {
        let useCase = StubEpisodesUseCase(result: .success(.catalogue))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)
        await viewModel.loadData()

        await viewModel.reloadFromScratch()

        #expect(useCase.fetchCallCount == 2)
        #expect(viewModel.episodesPublished?.count == 3)
        #expect(viewModel.loadingPublished == false)
    }

    @Test("reloadFromScratch keeps the search text")
    func reloadFromScratchKeepsTheSearch() async {
        let useCase = StubEpisodesUseCase(result: .success(.catalogue))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)
        await viewModel.loadData()
        viewModel.updateSearchText("pilot")

        await viewModel.reloadFromScratch()

        #expect(viewModel.searchQueryPublished.text == "pilot")
    }

    // MARK: - The generation counter

    @Test("a stale reload never publishes over a newer one")
    func aStaleReloadNeverPublishes() async {
        let useCase = StubEpisodesUseCase(result: .success(.catalogue))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)
        await viewModel.loadData()

        useCase.hold(call: 2)
        viewModel.retryLoad()
        await useCase.waitUntilCalled(2)
        let staleReload = viewModel.reloadTask

        useCase.setResult(.success([.make(name: "Newer", season: 9, number: 9)]))
        viewModel.retryLoad()
        await viewModel.settle()

        #expect(viewModel.episodesPublished?.map(\.name) == ["Newer"])

        useCase.release(call: 2)
        await staleReload?.value

        #expect(viewModel.episodesPublished?.map(\.name) == ["Newer"])
        #expect(viewModel.loadingPublished == false)
    }
}

// MARK: - Test helpers

private extension EpisodesViewModel {
    /// Awaits the pending reload task, since `retryLoad` is synchronous.
    func settle() async {
        await reloadTask?.value
    }
}

private extension Array where Element == EpisodeModel {
    static var catalogue: [EpisodeModel] {
        [.make(name: "Pilot", season: 1, number: 1),
         .make(name: "Lawnmower Dog", season: 1, number: 2),
         .make(name: "A Rickle in Time", season: 2, number: 1)]
    }
}
