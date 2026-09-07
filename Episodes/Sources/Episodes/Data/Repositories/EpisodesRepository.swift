//
//  EpisodesRepository.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

protocol EpisodesRepositoryContract: Sendable {
    /// The whole catalogue, in server order. There is no page parameter because
    /// the screen has no pagination: see the walk below for why fetching
    /// everything is the cheaper option here.
    func fetchEpisodes() async throws -> [EpisodeModel]
    /// Forgets every cached page. The next fetch goes to the network.
    func purgeCache() async throws
}

/// Decides, per page, whether the answer comes from disk or from the network —
/// and walks every page so the caller gets the complete catalogue in one call.
///
/// **Why the whole catalogue.** There are 51 episodes across 3 pages of 20, and
/// the screen searches them locally (see `EpisodesSearchQuery`). A local search
/// over a partially loaded list is a lie — it would confidently report no
/// results for an episode sitting on page 3 — so "all of it or none of it" is
/// what makes the search on this screen honest. Three requests once a week is a
/// price the characters list could not pay (42 pages, growing) and this one can.
///
/// **The per-page policy** is the characters repository's, unchanged, because
/// the constraint is the same: rickandmortyapi answers **429** once a client has
/// made too many requests in a short window, and a screen that refetches on
/// every appearance walks into that quickly. The order of the four steps is the
/// whole policy:
///
/// 1. Read the cache, but never let a cache failure fail the request. A cache is
///    an optimisation; if it is broken the app should be slower, not broken.
/// 2. Fresh entry wins outright — no network at all.
/// 3. Otherwise go to the network and write what comes back. The write is also
///    best-effort: a full disk must not turn a successful fetch into an error.
/// 4. If the network fails and a *stale* entry exists, serve it. A throttled or
///    offline fetch still renders last week's episodes, which is what the user
///    wants and what an empty error screen fails to give them. Cancellation is
///    the one exception — it means the screen went away, not that the fetch
///    failed, and swallowing it would defeat structured concurrency.
///
/// Applying it per page rather than to the walk as a whole is what lets a
/// half-cached catalogue cost only the missing requests.
final class EpisodesRepository: EpisodesRepositoryContract {
    private let remoteDataSource: EpisodesRemoteDataSourceContract
    private let localDataSource: EpisodesLocalDataSourceContract
    private let mapper: EpisodeEntityMapperContract

    init(remoteDataSource: EpisodesRemoteDataSourceContract,
         localDataSource: EpisodesLocalDataSourceContract,
         mapper: EpisodeEntityMapperContract) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
        self.mapper = mapper
    }

    /// Page 1, then wherever `info.next` points, until it points nowhere.
    ///
    /// The walk is driven by the server's own `next` rather than by counting to
    /// `info.pages`, so it stays correct if the catalogue grows. Two guards keep
    /// a malformed answer from looping forever, and both are cheap enough to be
    /// worth having even though the live API has never needed them: a page is
    /// never visited twice, and the walk stops once it has fetched as many pages
    /// as the first response said exist. A page that fails and has no stale
    /// entry fails the whole load — half a catalogue would silently break the
    /// local search, which is the one thing this method exists to make safe.
    func fetchEpisodes() async throws -> [EpisodeModel] {
        var episodes: [EpisodeModel] = []
        var visited: Set<Int> = []
        var pageCount: Int?
        var nextPage: Int? = 1

        while let page = nextPage {
            guard visited.insert(page).inserted else { break }
            if let pageCount, visited.count > pageCount { break }

            let entity = try await fetchPage(page)
            pageCount = pageCount ?? entity.info.pages
            episodes.append(contentsOf: map(entity))
            nextPage = entity.info.next
        }

        return episodes
    }

    func purgeCache() async throws {
        try await localDataSource.removeAll()
    }

    /// One page, through the four-step policy. See the type's documentation.
    private func fetchPage(_ page: Int) async throws -> EpisodesPageEntity {
        // Building the query here — and only here — is what keeps the cache
        // honest: the key is derived from the query, so each page addresses its
        // own entry without a single extra line in the local data source.
        let query = EpisodesQuery(page: page)

        // `try?`: an unreadable cache is a miss, not a failure. Step 1.
        let cached = try? await localDataSource.episodesPage(for: query)

        if let cached, !cached.isExpired {
            return cached.value
        }

        do {
            let fetched = try await remoteDataSource.fetchEpisodesPage(query)
            do {
                try await localDataSource.store(fetched, for: query)
            } catch {
                // Step 3: the fetch succeeded, so the caller still gets its page.
                print("[ERROR] Could not cache episodes page \(page): \(error.localizedDescription)")
            }
            return fetched
        } catch let error as CancellationError {
            throw error
        } catch {
            guard let cached else { throw error }
            return cached.value
        }
    }

    /// Mapping happens here, on every read, from disk and network alike — which
    /// is why the cache stores entities. A single entity that fails to map is
    /// logged and skipped rather than failing the page: one episode with an
    /// unparseable code should not blank the whole catalogue.
    private func map(_ page: EpisodesPageEntity) -> [EpisodeModel] {
        page.results.compactMap { entity -> EpisodeModel? in
            do {
                return try mapper.map(entity)
            } catch {
                // Log error without stopping the whole parsing process.
                print("[ERROR] \(error.localizedDescription)")
                return nil
            }
        }
    }
}
