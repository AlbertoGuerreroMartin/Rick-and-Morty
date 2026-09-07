//
//  EpisodesUseCase.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

protocol EpisodesUseCaseContract: Sendable {
    func fetchEpisodes() async throws -> [EpisodeModel]
}

/// A pass-through today, and worth having anyway: it is the seam the view model
/// is written against, so the presentation layer never names a repository, and
/// the day this screen needs something the repository alone cannot answer — a
/// character lookup joined onto an episode, say — that logic lands here instead
/// of in the view model.
final class EpisodesUseCase: EpisodesUseCaseContract {
    let repository: EpisodesRepositoryContract

    init(repository: EpisodesRepositoryContract) {
        self.repository = repository
    }

    func fetchEpisodes() async throws -> [EpisodeModel] {
        try await repository.fetchEpisodes()
    }

}
