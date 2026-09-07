//
//  EpisodesUseCaseTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Episodes

/// A pass-through, and worth a test anyway: this is the seam the view model is
/// written against, so a call that quietly stopped reaching the repository would
/// be an empty screen with nothing in the log to explain it.
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

    @Test("purgeCache forwards to the repository")
    func purgeForwards() async throws {
        let repository = FakeEpisodesRepository(episodes: [])
        let useCase = EpisodesUseCase(repository: repository)

        try await useCase.purgeCache()

        #expect(await repository.purgeCallCount == 1)
    }

    @Test("a failed purge reaches the caller")
    func purgeRethrows() async {
        let useCase = EpisodesUseCase(repository: FakeEpisodesRepository(error: TestError()))

        await #expect(throws: TestError.self) {
            try await useCase.purgeCache()
        }
    }
}

private actor FakeEpisodesRepository: EpisodesRepositoryContract {
    private let episodes: [EpisodeModel]
    private let error: (any Error)?
    private(set) var fetchCallCount = 0
    private(set) var purgeCallCount = 0

    init(episodes: [EpisodeModel] = [], error: (any Error)? = nil) {
        self.episodes = episodes
        self.error = error
    }

    func fetchEpisodes() async throws -> [EpisodeModel] {
        fetchCallCount += 1
        if let error { throw error }
        return episodes
    }

    func purgeCache() async throws {
        purgeCallCount += 1
        if let error { throw error }
    }
}
