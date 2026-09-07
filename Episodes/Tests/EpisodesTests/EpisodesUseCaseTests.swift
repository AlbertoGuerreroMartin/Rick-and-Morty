//
//  EpisodesUseCaseTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Episodes

/// The use case is where the catalogue and the HBO Max links become one list of
/// rows, so these tests are that join: what it matches on, what it does when
/// only one of the two answers arrives, and that it asks for both at once.
///
/// The asymmetry between the two failures is the point of most of them. A
/// catalogue that will not load is the screen; links that will not load are a
/// missing button, and an unofficial third-party endpoint must never be able to
/// take the screen down with it.
@Suite("EpisodesUseCase")
struct EpisodesUseCaseTests {

    @Test("fetchEpisodes forwards to the repository and returns its answer")
    func fetchForwards() async throws {
        let repository = FakeEpisodesRepository(episodes: [.make(name: "Pilot")])
        let useCase = EpisodesUseCase(repository: repository)

        #expect(try await useCase.fetchEpisodes().map(\.name) == ["Pilot"])
        #expect(await repository.fetchCallCount == 1)
    }

    @Test("a repository failure reaches the caller")
    func fetchRethrows() async {
        let useCase = EpisodesUseCase(repository: FakeEpisodesRepository(error: TestError()))

        await #expect(throws: TestError.self) {
            _ = try await useCase.fetchEpisodes()
        }
    }

    // MARK: - The join

    /// Season and number, because they are the only thing the two services
    /// agree on: JustWatch numbers episodes and rickandmortyapi codes them.
    @Test("each episode gets the link for its own season and number")
    func linksAreJoinedByNumber() async throws {
        let repository = FakeEpisodesRepository(
            episodes: [.make(name: "Pilot", season: 1, number: 1),
                       .make(name: "Lawnmower Dog", season: 1, number: 2),
                       .make(name: "A Rickle in Time", season: 2, number: 1)],
            links: HBOMaxLinks(urls: [
                EpisodeNumber(season: 1, number: 1): URL(string: "https://play.hbomax.com/video/watch/1")!,
                EpisodeNumber(season: 2, number: 1): URL(string: "https://play.hbomax.com/video/watch/2")!
            ])
        )

        let episodes = try await EpisodesUseCase(repository: repository).fetchEpisodes()

        #expect(episodes.map(\.hboMaxURL?.absoluteString) == [
            "https://play.hbomax.com/video/watch/1",
            nil,
            "https://play.hbomax.com/video/watch/2"
        ])
    }

    /// An episode HBO Max does not carry is not an error and not a special case:
    /// it is simply a row with no button, which is also what every row looks
    /// like when the lookup returns nothing at all.
    @Test("no links at all is a catalogue with no buttons")
    func emptyLinksLeaveEveryEpisodeUnlinked() async throws {
        let repository = FakeEpisodesRepository(episodes: [.make(name: "Pilot")], links: .empty)

        let episodes = try await EpisodesUseCase(repository: repository).fetchEpisodes()

        #expect(episodes.allSatisfy { $0.hboMaxURL == nil })
    }

    /// The whole reason the two fetches are separate calls: JustWatch is
    /// unofficial and can fail at any time, and the list of episodes must load
    /// anyway.
    @Test("a links failure costs the buttons, not the screen")
    func aLinksFailureIsSurvivable() async throws {
        let repository = FakeEpisodesRepository(episodes: [.make(name: "Pilot")],
                                                linksError: TestError())

        let episodes = try await EpisodesUseCase(repository: repository).fetchEpisodes()

        #expect(episodes.map(\.name) == ["Pilot"])
        #expect(episodes.allSatisfy { $0.hboMaxURL == nil })
    }

    /// The other half of that asymmetry: the catalogue is the screen, so its
    /// failure still throws even when the links came back perfectly well.
    @Test("an episodes failure still throws even when the links arrived")
    func anEpisodesFailureStillThrows() async {
        let repository = FakeEpisodesRepository(
            error: TestError(),
            links: HBOMaxLinks(urls: [EpisodeNumber(season: 1, number: 1): URL(string: "https://play.hbomax.com/video/watch/1")!])
        )

        await #expect(throws: TestError.self) {
            _ = try await EpisodesUseCase(repository: repository).fetchEpisodes()
        }
    }

    /// Cancellation means the screen went away rather than that JustWatch is
    /// down, so it is the one links failure that is not swallowed — a task that
    /// answered anyway would defeat structured concurrency.
    @Test("a cancelled links fetch is not treated as a missing link")
    func cancellationPropagates() async {
        let repository = FakeEpisodesRepository(episodes: [.make(name: "Pilot")],
                                                linksError: CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await EpisodesUseCase(repository: repository).fetchEpisodes()
        }
    }

    /// Sequential fetches would add JustWatch's latency to a load the user is
    /// watching a spinner through, for two answers that need nothing from each
    /// other. The fake holds the catalogue open until the links fetch has
    /// started, so this can only finish if both are in flight at once.
    @Test("both fetches are in flight at the same time")
    func bothFetchesRunConcurrently() async throws {
        let repository = FakeEpisodesRepository(episodes: [.make(name: "Pilot")],
                                                holdEpisodesUntilLinksStart: true)

        _ = try await EpisodesUseCase(repository: repository).fetchEpisodes()

        #expect(await repository.fetchCallCount == 1)
        #expect(await repository.linksCallCount == 1)
    }
}

private actor FakeEpisodesRepository: EpisodesRepositoryContract {
    private let episodes: [EpisodeModel]
    private let error: (any Error)?
    private let links: HBOMaxLinks
    private let linksError: (any Error)?
    /// Makes the two calls prove they overlap: the catalogue cannot finish until
    /// the links fetch has been entered, which a sequential use case would never
    /// allow. Bounded, so a use case that stopped fetching both fails on the
    /// assertions rather than hanging the suite.
    private let holdEpisodesUntilLinksStart: Bool
    private(set) var fetchCallCount = 0
    private(set) var linksCallCount = 0

    init(episodes: [EpisodeModel] = [],
         error: (any Error)? = nil,
         links: HBOMaxLinks = .empty,
         linksError: (any Error)? = nil,
         holdEpisodesUntilLinksStart: Bool = false) {
        self.episodes = episodes
        self.error = error
        self.links = links
        self.linksError = linksError
        self.holdEpisodesUntilLinksStart = holdEpisodesUntilLinksStart
    }

    func fetchEpisodes() async throws -> [EpisodeModel] {
        fetchCallCount += 1

        if holdEpisodesUntilLinksStart {
            for _ in 0..<10_000 {
                if linksCallCount > 0 { break }
                // An actor is reentrant, so suspending here lets the links call
                // in — which is exactly what is being asserted.
                await Task.yield()
            }
        }

        if let error { throw error }
        return episodes
    }

    func fetchHBOMaxLinks() async throws -> HBOMaxLinks {
        linksCallCount += 1
        if let linksError { throw linksError }
        return links
    }
}
