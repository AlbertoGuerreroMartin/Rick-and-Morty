//
//  CharacterDetailUseCase.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

protocol CharacterDetailUseCaseContract: Sendable {
    func fetchCharacterDetail(id: String) async throws -> CharacterDetailModel
}

/// Joins one character to its HBO Max links, fetched concurrently. Links are best-effort.
final class CharacterDetailUseCase: CharacterDetailUseCaseContract {
    let repository: CharactersRepositoryContract

    init(repository: CharactersRepositoryContract) {
        self.repository = repository
    }

    func fetchCharacterDetail(id: String) async throws -> CharacterDetailModel {
        async let detail = repository.fetchCharacterDetail(id: id)
        async let links = repository.fetchHBOMaxLinks()

        let character = try await detail

        let hboMaxLinks: HBOMaxLinks
        do {
            hboMaxLinks = try await links
        } catch let error as CancellationError {
            // Not JustWatch's failure — it means the screen went away.
            throw error
        } catch {
            print("[ERROR] Could not fetch the HBO Max links: \(error.localizedDescription)")
            hboMaxLinks = .empty
        }

        return character.withEpisodes(character.episodes.map { episode in
            episode.withHBOMaxURL(hboMaxLinks.url(season: episode.season, number: episode.number))
        })
    }
}
