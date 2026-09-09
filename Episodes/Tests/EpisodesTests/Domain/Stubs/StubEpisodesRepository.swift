//
//  StubEpisodesRepository.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
@testable import Episodes

actor StubEpisodesRepository: EpisodesRepositoryContract {
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
