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

/// Joins the catalogue to the HBO Max links, which is the join this type was
/// written in anticipation of: it is the seam the view model is bound to, so the
/// presentation layer never names a repository, and work that needs *two*
/// answers to produce one belongs here rather than in a view model that would
/// then have to know about two data sources.
///
/// Two things about the join are deliberate.
///
/// **Both requests go out at once.** The catalogue is three sequential requests
/// to rickandmortyapi and the links are one to JustWatch; they share nothing, so
/// running them one after the other would add the slower one's latency to a load
/// the user is watching a spinner through for no reason at all.
///
/// **The links are best-effort and the episodes are not.** JustWatch is an
/// unofficial endpoint that can change or disappear without notice, and the
/// worst thing its absence costs is a play button. Failing the whole screen over
/// it would let a third party this app has no relationship with take down a list
/// of episodes that loaded perfectly well — so a failure is one line in the log
/// and no buttons. A failure to load the episodes themselves still throws:
/// that one is the screen.
final class EpisodesUseCase: EpisodesUseCaseContract {
    let repository: EpisodesRepositoryContract

    init(repository: EpisodesRepositoryContract) {
        self.repository = repository
    }

    func fetchEpisodes() async throws -> [EpisodeModel] {
        // Both `async let`s start here; neither waits for the other.
        async let episodes = repository.fetchEpisodes()
        async let links = repository.fetchHBOMaxLinks()

        // Awaited first, so a catalogue failure leaves the scope immediately and
        // the links fetch is cancelled with it rather than being logged as a
        // failure nobody was going to use.
        let catalogue = try await episodes

        let hboMaxLinks: HBOMaxLinks
        do {
            hboMaxLinks = try await links
        } catch let error as CancellationError {
            // The one failure that is not survivable, and it is not JustWatch's:
            // it means the screen went away. Answering with a catalogue here
            // would defeat structured concurrency exactly the way the
            // repository's policy is careful not to.
            throw error
        } catch {
            // Everything else is a missing button. One line, and on with the load.
            print("[ERROR] Could not fetch the HBO Max links: \(error.localizedDescription)")
            hboMaxLinks = .empty
        }

        return catalogue.map { episode in
            episode.withHBOMaxURL(hboMaxLinks.url(season: episode.season, number: episode.number))
        }
    }
}
