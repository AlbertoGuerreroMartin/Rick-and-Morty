//
//  EpisodesUseCaseTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Episodes

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

    @Test("no links at all is a catalogue with no buttons")
    func emptyLinksLeaveEveryEpisodeUnlinked() async throws {
        let repository = FakeEpisodesRepository(episodes: [.make(name: "Pilot")], links: .empty)

        let episodes = try await EpisodesUseCase(repository: repository).fetchEpisodes()

        #expect(episodes.allSatisfy { $0.hboMaxURL == nil })
    }

    @Test("a links failure costs the buttons, not the screen")
    func aLinksFailureIsSurvivable() async throws {
        let repository = FakeEpisodesRepository(episodes: [.make(name: "Pilot")],
                                                linksError: TestError())

        let episodes = try await EpisodesUseCase(repository: repository).fetchEpisodes()

        #expect(episodes.map(\.name) == ["Pilot"])
        #expect(episodes.allSatisfy { $0.hboMaxURL == nil })
    }

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

    @Test("a cancelled links fetch is not treated as a missing link")
    func cancellationPropagates() async {
        let repository = FakeEpisodesRepository(episodes: [.make(name: "Pilot")],
                                                linksError: CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await EpisodesUseCase(repository: repository).fetchEpisodes()
        }
    }

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
    /// Bounded loop so a use case that never starts the links fetch fails the assertions rather
    /// than hanging the suite.
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
