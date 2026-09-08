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

/// Both requests go out concurrently. Links are best-effort (failure costs only a play button);
/// a catalogue failure still throws.
final class EpisodesUseCase: EpisodesUseCaseContract {
    let repository: EpisodesRepositoryContract

    init(repository: EpisodesRepositoryContract) {
        self.repository = repository
    }

    func fetchEpisodes() async throws -> [EpisodeModel] {
        async let episodes = repository.fetchEpisodes()
        async let links = repository.fetchHBOMaxLinks()

        // Awaited first so a catalogue failure cancels the links fetch with it.
        let catalogue = try await episodes

        let hboMaxLinks: HBOMaxLinks
        do {
            hboMaxLinks = try await links
        } catch let error as CancellationError {
            throw error
        } catch {
            print("[ERROR] Could not fetch the HBO Max links: \(error.localizedDescription)")
            hboMaxLinks = .empty
        }

        return catalogue.map { episode in
            episode.withHBOMaxURL(hboMaxLinks.url(season: episode.season, number: episode.number))
        }
    }
}
