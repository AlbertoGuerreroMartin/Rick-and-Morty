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

/// Joins one character to the HBO Max links, which is the join this type exists
/// for: it is the seam the view model is bound to, so the presentation layer
/// never names a repository, and work that needs *two* answers to produce one
/// belongs here rather than in a view model that would then have to know about
/// two data sources.
///
/// Two things about the join are deliberate.
///
/// **Both requests go out at once.** The character is one request to
/// rickandmortyapi and the links are one to JustWatch; they share nothing, so
/// running them one after the other would add the slower one's latency to a load
/// the user is watching a spinner through for no reason at all.
///
/// **The links are best-effort and the character is not.** JustWatch is an
/// unofficial endpoint that can change or disappear without notice, and the
/// worst thing its absence costs is a play button. Failing the whole screen over
/// it would let a third party this app has no relationship with take down a
/// character page that loaded perfectly well — so a failure is one line in the
/// log and no buttons. A failure to load the character still throws: that one
/// *is* the screen.
final class CharacterDetailUseCase: CharacterDetailUseCaseContract {
    let repository: CharactersRepositoryContract

    init(repository: CharactersRepositoryContract) {
        self.repository = repository
    }

    func fetchCharacterDetail(id: String) async throws -> CharacterDetailModel {
        // Both `async let`s start here; neither waits for the other.
        async let detail = repository.fetchCharacterDetail(id: id)
        async let links = repository.fetchHBOMaxLinks()

        // Awaited first, so a character failure leaves the scope immediately and
        // the links fetch is cancelled with it rather than being logged as a
        // failure nobody was going to use.
        let character = try await detail

        let hboMaxLinks: HBOMaxLinks
        do {
            hboMaxLinks = try await links
        } catch let error as CancellationError {
            // The one failure that is not survivable, and it is not JustWatch's:
            // it means the screen went away. Answering with a character here
            // would defeat structured concurrency exactly the way the
            // repository's policy is careful not to.
            throw error
        } catch {
            // Everything else is a missing button. One line, and on with the load.
            print("[ERROR] Could not fetch the HBO Max links: \(error.localizedDescription)")
            hboMaxLinks = .empty
        }

        // Rebuilt rather than mutated: the episodes arrive from the mapper
        // without links and are completed here, in one pass, so nothing
        // downstream ever sees a half-joined model.
        return character.withEpisodes(character.episodes.map { episode in
            episode.withHBOMaxURL(hboMaxLinks.url(season: episode.season, number: episode.number))
        })
    }
}
