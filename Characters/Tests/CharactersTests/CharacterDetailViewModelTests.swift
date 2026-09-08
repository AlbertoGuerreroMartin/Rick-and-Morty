//
//  CharacterDetailViewModelTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Characters

@Suite("CharacterDetailViewModel")
@MainActor
struct CharacterDetailViewModelTests {

    @Test("loadData publishes the character and clears the spinner")
    func loadDataPublishesTheDetail() async {
        let useCase = StubCharacterDetailUseCase(result: .success(.make(name: "Rick Sanchez")))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)

        await viewModel.loadData()

        #expect(viewModel.detailPublished?.name == "Rick Sanchez")
        #expect(viewModel.loadingPublished == false)
        #expect(viewModel.loadFailedPublished == false)
    }

    @Test("the fetch asks for the character the screen was pushed with")
    func theIdReachesTheUseCase() async {
        let useCase = StubCharacterDetailUseCase(result: .success(.make()))
        let viewModel = CharacterDetailViewModel(id: "42", characterDetailUseCase: useCase)

        await viewModel.loadData()

        #expect(useCase.requestedIDs == ["42"])
    }

    @Test("a failed load leaves no character behind and raises the failure flag")
    func loadDataPublishesNilOnFailure() async {
        let useCase = StubCharacterDetailUseCase(result: .failure(StubCharacterDetailError()))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)

        await viewModel.loadData()

        #expect(viewModel.detailPublished == nil)
        #expect(viewModel.loadFailedPublished == true)
        #expect(viewModel.loadingPublished == false)
    }

    @Test("a failed reload clears the character that was on screen")
    func aFailedReloadClearsTheDetail() async {
        let useCase = StubCharacterDetailUseCase(result: .success(.make(name: "Rick Sanchez")))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)
        await viewModel.loadData()

        useCase.setResult(.failure(StubCharacterDetailError()))
        viewModel.retryLoad()
        await viewModel.settle()

        #expect(viewModel.detailPublished == nil)
        #expect(viewModel.loadFailedPublished == true)
    }

    @Test("a second loadData does not refetch")
    func loadDataIsIdempotent() async {
        let useCase = StubCharacterDetailUseCase(result: .success(.make()))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)

        await viewModel.loadData()
        await viewModel.loadData()

        #expect(useCase.fetchCallCount == 1)
    }

    @Test("loadData tries again after a failure")
    func loadDataRetriesAfterAFailure() async {
        let useCase = StubCharacterDetailUseCase(result: .failure(StubCharacterDetailError()))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)
        await viewModel.loadData()

        useCase.setResult(.success(.make(name: "Rick Sanchez")))
        await viewModel.loadData()

        #expect(useCase.fetchCallCount == 2)
        #expect(viewModel.detailPublished?.name == "Rick Sanchez")
    }

    @Test("the HBO Max link survives the trip to the sections")
    func loadDataPublishesTheHBOMaxLink() async {
        let detail = CharacterDetailModel.make(episodes: [
            .make(name: "Pilot", season: 1, number: 1,
                  hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/1")),
            .make(name: "Lawnmower Dog", season: 1, number: 2)
        ])
        let useCase = StubCharacterDetailUseCase(result: .success(detail))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)

        await viewModel.loadData()

        #expect(viewModel.detailPublished?.episodes.map(\.hboMaxURL?.absoluteString)
                == ["https://play.hbomax.com/video/watch/1", nil])
    }

    // MARK: - Retry

    @Test("retryLoad fetches again and clears the failure on success")
    func retryLoadClearsTheFailure() async {
        let useCase = StubCharacterDetailUseCase(result: .failure(StubCharacterDetailError()))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)
        await viewModel.loadData()

        #expect(viewModel.loadFailedPublished == true)

        useCase.setResult(.success(.make(name: "Rick Sanchez")))
        viewModel.retryLoad()
        await viewModel.settle()

        #expect(useCase.fetchCallCount == 2)
        #expect(viewModel.loadFailedPublished == false)
        #expect(viewModel.detailPublished?.name == "Rick Sanchez")
        #expect(viewModel.loadingPublished == false)
    }

    @Test("retryLoad is not guarded by a previous success")
    func retryLoadAlwaysFetches() async {
        let useCase = StubCharacterDetailUseCase(result: .success(.make()))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)
        await viewModel.loadData()

        viewModel.retryLoad()
        await viewModel.settle()

        #expect(useCase.fetchCallCount == 2)
    }

    // MARK: - Reload after a cache clear

    @Test("reloadFromScratch fetches the character again")
    func reloadFromScratchFetchesAgain() async {
        let useCase = StubCharacterDetailUseCase(result: .success(.make(name: "Rick Sanchez")))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)
        await viewModel.loadData()

        await viewModel.reloadFromScratch()

        #expect(useCase.fetchCallCount == 2)
        #expect(viewModel.detailPublished?.name == "Rick Sanchez")
        #expect(viewModel.loadingPublished == false)
    }

    @Test("reloadFromScratch clears what was on screen before it refetches")
    func reloadFromScratchClearsFirst() async {
        let useCase = StubCharacterDetailUseCase(result: .success(.make(name: "Rick Sanchez")))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)
        await viewModel.loadData()

        useCase.hold(call: 2)
        let reload = Task { await viewModel.reloadFromScratch() }
        await useCase.waitUntilCalled(2)

        #expect(viewModel.detailPublished == nil)
        #expect(viewModel.loadingPublished == true)

        useCase.release(call: 2)
        await reload.value

        #expect(viewModel.detailPublished?.name == "Rick Sanchez")
    }

    // MARK: - The generation counter

    /// `Task.cancel()` does not guarantee a stale reload stops before it publishes.
    @Test("a stale reload never publishes over a newer one")
    func aStaleReloadNeverPublishes() async {
        let useCase = StubCharacterDetailUseCase(result: .success(.make(name: "Rick Sanchez")))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)
        await viewModel.loadData()

        useCase.hold(call: 2)
        viewModel.retryLoad()
        await useCase.waitUntilCalled(2)
        let staleReload = viewModel.reloadTask

        useCase.setResult(.success(.make(name: "Newer")))
        viewModel.retryLoad()
        await viewModel.settle()

        #expect(viewModel.detailPublished?.name == "Newer")

        useCase.release(call: 2)
        await staleReload?.value

        #expect(viewModel.detailPublished?.name == "Newer")
        #expect(viewModel.loadingPublished == false)
    }
}

// MARK: - Test helpers

private extension CharacterDetailViewModel {
    /// Awaits the pending reload task, so tests are deterministic instead of sleep-and-hope.
    func settle() async {
        await reloadTask?.value
    }
}

struct StubCharacterDetailError: Error {}

/// `final class` behind a lock, not an actor: an actor would hop isolation on
/// every call, changing the interleaving the generation test checks.
final class StubCharacterDetailUseCase: CharacterDetailUseCaseContract, @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<CharacterDetailModel, StubCharacterDetailError>
    private var fetchCount = 0
    private var ids: [String] = []
    /// Fetches held open by ordinal until the test releases them. Cancellation does not
    /// release them: the test is about what a late answer does.
    private var heldCalls: Set<Int> = []

    init(result: Result<CharacterDetailModel, StubCharacterDetailError>) {
        self.result = result
    }

    var fetchCallCount: Int { lock.withLock { fetchCount } }

    var requestedIDs: [String] { lock.withLock { ids } }

    func setResult(_ result: Result<CharacterDetailModel, StubCharacterDetailError>) {
        lock.withLock { self.result = result }
    }

    func hold(call: Int) {
        lock.withLock { _ = heldCalls.insert(call) }
    }

    func release(call: Int) {
        lock.withLock { _ = heldCalls.remove(call) }
    }

    /// Suspends until `count` fetches have been made. Bounded, so a test that never
    /// gets its call fails on assertions rather than hanging the suite.
    func waitUntilCalled(_ count: Int) async {
        for _ in 0..<100_000 {
            if fetchCallCount >= count { return }
            await Task.yield()
        }
    }

    func fetchCharacterDetail(id: String) async throws -> CharacterDetailModel {
        // Snapshotted at call time, so a held fetch answers with what was configured
        // when it started, not with what a later test line sets up.
        let (call, snapshot) = lock.withLock { () -> (Int, Result<CharacterDetailModel, StubCharacterDetailError>) in
            fetchCount += 1
            ids.append(id)
            return (fetchCount, result)
        }

        while lock.withLock({ heldCalls.contains(call) }) {
            await Task.yield()
        }
        await Task.yield()
        return try snapshot.get()
    }
}

// MARK: - Fixtures

extension CharacterDetailModel {
    static func make(id: String = "1",
                     name: String = "Rick Sanchez",
                     status: CharacterStatus = .alive,
                     species: String = "Human",
                     type: String? = nil,
                     gender: CharacterGender = .male,
                     image: URL = URL(string: "https://example.com/1.jpeg")!,
                     origin: CharacterDetailPlaceModel? = CharacterDetailPlaceModel(
                        name: "Earth (C-137)", type: "Planet", dimension: "Dimension C-137"
                     ),
                     location: CharacterDetailPlaceModel? = CharacterDetailPlaceModel(
                        name: "Citadel of Ricks", type: "Space station", dimension: "unknown"
                     ),
                     episodes: [CharacterDetailEpisodeModel] = [
                        .make(name: "Pilot", season: 1, number: 1)
                     ]) -> CharacterDetailModel {
        CharacterDetailModel(id: id,
                             name: name,
                             status: status,
                             species: species,
                             type: type,
                             gender: gender,
                             image: image,
                             origin: origin,
                             location: location,
                             episodes: episodes)
    }
}

extension CharacterDetailEpisodeModel {
    /// `code` is derived from `season`/`number` rather than passed in, so the two cannot disagree.
    static func make(id: String? = nil,
                     name: String = "Pilot",
                     airDate: String = "December 2, 2013",
                     season: Int = 1,
                     number: Int = 1,
                     hboMaxURL: URL? = nil) -> CharacterDetailEpisodeModel {
        let code = String(format: "S%02dE%02d", season, number)
        return CharacterDetailEpisodeModel(id: id ?? code,
                                           name: name,
                                           airDate: airDate,
                                           code: code,
                                           season: season,
                                           number: number,
                                           hboMaxURL: hboMaxURL)
    }
}
