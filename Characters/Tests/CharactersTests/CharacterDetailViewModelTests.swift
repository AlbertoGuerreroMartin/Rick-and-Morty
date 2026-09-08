//
//  CharacterDetailViewModelTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Characters

/// Every layer takes its collaborator through its initializer, so a test can
/// stand a view model on a stub use case with no container or registry setup.
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

    /// The id is the screen's identity, and it is the only thing the navigation
    /// carries — a view model that asked for anything else would show whichever
    /// character the server answered with.
    @Test("the fetch asks for the character the screen was pushed with")
    func theIdReachesTheUseCase() async {
        let useCase = StubCharacterDetailUseCase(result: .success(.make()))
        let viewModel = CharacterDetailViewModel(id: "42", characterDetailUseCase: useCase)

        await viewModel.loadData()

        #expect(useCase.requestedIDs == ["42"])
    }

    /// `nil` rather than a half-built placeholder: there is no partial character
    /// to show, so the header reads the failure flag and draws its Retry over an
    /// empty screen rather than over a stale name.
    @Test("a failed load leaves no character behind and raises the failure flag")
    func loadDataPublishesNilOnFailure() async {
        let useCase = StubCharacterDetailUseCase(result: .failure(StubCharacterDetailError()))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)

        await viewModel.loadData()

        #expect(viewModel.detailPublished == nil)
        #expect(viewModel.loadFailedPublished == true)
        #expect(viewModel.loadingPublished == false)
    }

    /// A failure after a successful load must not leave the previous character
    /// on screen under an error: the two would contradict each other.
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

    /// `.task` fires again every time the screen reappears — after a sheet, or
    /// on a restored navigation stack. The character is not going to have
    /// changed while the user was looking at it.
    @Test("a second loadData does not refetch")
    func loadDataIsIdempotent() async {
        let useCase = StubCharacterDetailUseCase(result: .success(.make()))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)

        await viewModel.loadData()
        await viewModel.loadData()

        #expect(useCase.fetchCallCount == 1)
    }

    /// A load that failed did not land, so a return to the screen is allowed to
    /// try again — the guard is about not re-fetching a character that is
    /// already on screen, not about giving up after one failure.
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

    /// The view model publishes the model the use case built, links included. It
    /// does no joining of its own — that is the use case's job — so what this
    /// pins is that nothing on the way to the sections drops the URL.
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

    /// Unlike a load, a retry is unconditional: re-asking for the same character
    /// after a success is what the button is for if it is ever offered again.
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

    /// What the screen runs when the developer tools announce a cleared cache:
    /// the character is fetched again and replaces what was on screen.
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

    /// The clear is invisible on its own, so the reload is what makes it
    /// observable — which means it has to go through the spinner rather than
    /// swapping one character for another behind the user's back.
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

    /// A request that has already left the device cannot be un-sent, and nothing
    /// about `Task.cancel()` guarantees it stops before it publishes. This is
    /// the race the counter exists for: a stale reload finishing after a newer
    /// one must be a no-op, not a screen that flickers back.
    @Test("a stale reload never publishes over a newer one")
    func aStaleReloadNeverPublishes() async {
        let useCase = StubCharacterDetailUseCase(result: .success(.make(name: "Rick Sanchez")))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)
        await viewModel.loadData()

        // The second fetch — the first retry — is held open.
        useCase.hold(call: 2)
        viewModel.retryLoad()
        await useCase.waitUntilCalled(2)
        let staleReload = viewModel.reloadTask

        // A newer reload takes ownership and finishes while the first is still
        // suspended.
        useCase.setResult(.success(.make(name: "Newer")))
        viewModel.retryLoad()
        await viewModel.settle()

        #expect(viewModel.detailPublished?.name == "Newer")

        // Only now does the stale fetch get its answer. It must change nothing.
        useCase.release(call: 2)
        await staleReload?.value

        #expect(viewModel.detailPublished?.name == "Newer")
        #expect(viewModel.loadingPublished == false)
    }
}

// MARK: - Test helpers

private extension CharacterDetailViewModel {
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

/// Named for this suite rather than `StubError`: the characters view model's
/// own suite declares a file-private one, and two `StubCharacterDetailError`s in one target
/// make every `Result<_, StubCharacterDetailError>` in both files ambiguous.
struct StubCharacterDetailError: Error {}

/// A `final class` behind a lock rather than an actor:
/// `CharacterDetailUseCaseContract` is a synchronous-to-declare, `Sendable`
/// protocol, and an actor could not satisfy it without every call hopping
/// isolation, which would change the very interleaving the generation test is
/// checking.
final class StubCharacterDetailUseCase: CharacterDetailUseCaseContract, @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<CharacterDetailModel, StubCharacterDetailError>
    private var fetchCount = 0
    private var ids: [String] = []
    /// Fetches that stay suspended until the test releases them, identified by
    /// their ordinal — the view model's requests are otherwise indistinguishable
    /// from one another, and holding *one* of them is the whole point.
    /// Cancellation does not release them on purpose: the test is about what a
    /// *late* answer does, and a fetch that unblocked itself on cancel would
    /// race the assertions.
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

    /// Suspends until `count` fetches have been made. Bounded, so a test that
    /// never gets its call fails on its assertions rather than hanging the suite.
    func waitUntilCalled(_ count: Int) async {
        for _ in 0..<100_000 {
            if fetchCallCount >= count { return }
            await Task.yield()
        }
    }

    func fetchCharacterDetail(id: String) async throws -> CharacterDetailModel {
        // The result is snapshotted at call time, so a held fetch answers with
        // what was configured when it *started* rather than with whatever a
        // later test line set up for a newer request.
        let (call, snapshot) = lock.withLock { () -> (Int, Result<CharacterDetailModel, StubCharacterDetailError>) in
            fetchCount += 1
            ids.append(id)
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
}

// MARK: - Fixtures

extension CharacterDetailModel {
    /// Every property defaults to something valid, so a test that is about one
    /// field says only that.
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
    /// The code is derived from the season and the number rather than passed in:
    /// a fixture whose `S01E02` disagreed with its `season`/`number` would be
    /// testing a state the mapper cannot produce.
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
