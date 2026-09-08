//
//  EpisodesRepository.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Storage

protocol EpisodesRepositoryContract: Sendable {
    func fetchEpisodes() async throws -> [EpisodeModel]
    func fetchHBOMaxLinks() async throws -> HBOMaxLinks
}

/// Walks every page so the caller gets the whole catalogue at once (search happens locally).
/// Per-page cache policy, shared with `fetchThroughCache`: cache failure is a miss, fresh entry
/// wins, otherwise fetch and best-effort write, and on failure serve stale if present.
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

    /// Walks via `info.next`, not a count. Guards a malformed answer from looping: no page
    /// visited twice, stops once `info.pages` worth are fetched.
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

    private func fetchPage(_ page: Int) async throws -> EpisodesPageEntity {
        let query = EpisodesQuery(page: page)

        return try await fetchThroughCache(
            label: "episodes page \(page)",
            cached: { try await localDataSource.episodesPage(for: query) },
            fetch: { try await remoteDataSource.fetchEpisodesPage(query) },
            store: { try await localDataSource.store($0, for: query) }
        )
    }

    /// One ~120 KB request for the whole show, not one per episode.
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

    private func fetchThroughCache<Value: Sendable>(
        label: String,
        cached: () async throws -> CacheEntry<Value>?,
        fetch: () async throws -> Value,
        store: (Value) async throws -> Void
    ) async throws -> Value {
        // `try?`: an unreadable cache is a miss, not a failure.
        let entry = try? await cached()

        if let entry, !entry.isExpired {
            return entry.value
        }

        do {
            let fetched = try await fetch()
            do {
                try await store(fetched)
            } catch {
                print("[ERROR] Could not cache \(label): \(error.localizedDescription)")
            }
            return fetched
        } catch let error as CancellationError {
            throw error
        } catch {
            guard let entry else { throw error }
            return entry.value
        }
    }

    /// A single entity that fails to map is logged and skipped rather than failing the page.
    private func map(_ page: EpisodesPageEntity) -> [EpisodeModel] {
        page.results.compactMap { entity -> EpisodeModel? in
            do {
                return try mapper.map(entity)
            } catch {
                print("[ERROR] \(error.localizedDescription)")
                return nil
            }
        }
    }
}
