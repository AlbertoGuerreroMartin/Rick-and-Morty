//
//  EpisodesRepository.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Storage

protocol EpisodesRepositoryContract: Sendable {
    /// The whole catalogue, in server order. There is no page parameter because
    /// the screen has no pagination: see the walk below for why fetching
    /// everything is the cheaper option here.
    func fetchEpisodes() async throws -> [EpisodeModel]

    /// Where to watch each episode on HBO Max, for every episode that is on it.
    ///
    /// Separate from `fetchEpisodes()` rather than folded into it: the two come
    /// from different services and can be asked for at the same time, and only
    /// the caller knows that a missing link is survivable while a missing
    /// catalogue is not. Joining them is `EpisodesUseCase`'s job.
    func fetchHBOMaxLinks() async throws -> HBOMaxLinks
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
/// half-cached catalogue cost only the missing requests — and the same four
/// steps, extracted into `fetchThroughCache(label:cached:fetch:store:)`, are
/// what the JustWatch lookup runs on too. It is a different server with a
/// different failure mode, but the reason for every one of the four steps is
/// unchanged, and two copies of a policy are two policies the moment one of them
/// is edited.
final class EpisodesRepository: EpisodesRepositoryContract {
    private let remoteDataSource: EpisodesRemoteDataSourceContract
    private let hboMaxLinksRemoteDataSource: HBOMaxLinksRemoteDataSourceContract
    private let localDataSource: EpisodesLocalDataSourceContract
    private let mapper: EpisodeEntityMapperContract
    private let linksMapper: HBOMaxLinksMapperContract

    init(remoteDataSource: EpisodesRemoteDataSourceContract,
         hboMaxLinksRemoteDataSource: HBOMaxLinksRemoteDataSourceContract,
         localDataSource: EpisodesLocalDataSourceContract,
         mapper: EpisodeEntityMapperContract,
         linksMapper: HBOMaxLinksMapperContract) {
        self.remoteDataSource = remoteDataSource
        self.hboMaxLinksRemoteDataSource = hboMaxLinksRemoteDataSource
        self.localDataSource = localDataSource
        self.mapper = mapper
        self.linksMapper = linksMapper
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

    /// One page, through the four-step policy. See the type's documentation.
    private func fetchPage(_ page: Int) async throws -> EpisodesPageEntity {
        // Building the query here — and only here — is what keeps the cache
        // honest: the key is derived from the query, so each page addresses its
        // own entry without a single extra line in the local data source.
        let query = EpisodesQuery(page: page)

        return try await fetchThroughCache(
            label: "episodes page \(page)",
            cached: { try await localDataSource.episodesPage(for: query) },
            fetch: { try await remoteDataSource.fetchEpisodesPage(query) },
            store: { try await localDataSource.store($0, for: query) }
        )
    }

    /// The show's offers, through the same four-step policy, then mapped.
    ///
    /// One request for the whole show rather than one per episode: JustWatch
    /// answers with every season and every offer in a single ~120 KB response,
    /// and 51 lookups against an unofficial endpoint to build one column of
    /// buttons would be the wrong trade by two orders of magnitude.
    ///
    /// Mapping happens here, on every read, so the cache stores the server's
    /// shape and the normalisation rules apply to a week-old entry exactly as
    /// they do to a fresh one.
    func fetchHBOMaxLinks() async throws -> HBOMaxLinks {
        let query = JustWatchShowOffersQuery()

        let offers = try await fetchThroughCache(
            label: "HBO Max links",
            cached: { try await localDataSource.showOffers(for: query) },
            fetch: { try await hboMaxLinksRemoteDataSource.fetchShowOffers(query) },
            store: { try await localDataSource.store($0, for: query) }
        )

        return linksMapper.map(offers)
    }

    /// The four-step policy itself, with the three things that differ — which
    /// entry to read, what to fetch, where to write it — handed in.
    ///
    /// Generic over the value rather than over the query: the query is already
    /// captured by all three closures at the call site, which is also the only
    /// place it can be built correctly. `label` appears in nothing but the log
    /// line, and is a parameter so that line still names *which* fetch could not
    /// be cached.
    ///
    /// - See: the type's documentation for what each of the four steps is for.
    private func fetchThroughCache<Value: Sendable>(
        label: String,
        cached: () async throws -> CacheEntry<Value>?,
        fetch: () async throws -> Value,
        store: (Value) async throws -> Void
    ) async throws -> Value {
        // `try?`: an unreadable cache is a miss, not a failure. Step 1.
        let entry = try? await cached()

        // Step 2.
        if let entry, !entry.isExpired {
            return entry.value
        }

        do {
            let fetched = try await fetch()
            do {
                try await store(fetched)
            } catch {
                // Step 3: the fetch succeeded, so the caller still gets its value.
                print("[ERROR] Could not cache \(label): \(error.localizedDescription)")
            }
            return fetched
        } catch let error as CancellationError {
            throw error
        } catch {
            // Step 4.
            guard let entry else { throw error }
            return entry.value
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
