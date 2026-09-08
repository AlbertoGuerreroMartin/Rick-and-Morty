//
//  CharactersRepository.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Foundation
import Storage

protocol CharactersRepositoryContract: Sendable {
    /// One page of the list for a given filter.
    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage

    /// One character, with everything the detail screen shows.
    func fetchCharacterDetail(id: String) async throws -> CharacterDetailModel

    /// Where to watch each episode on HBO Max, for every episode that is on it.
    func fetchHBOMaxLinks() async throws -> HBOMaxLinks
}

/// Decides, per request, whether the answer comes from disk or from the network.
/// rickandmortyapi returns 429 when rate-limited; a fresh cache entry skips the network,
/// and a failed fetch falls back to a stale entry unless it was cancelled.
final class CharactersRepository: CharactersRepositoryContract {
    private let remoteDataSource: CharactersRemoteDataSourceContract
    private let hboMaxLinksRemoteDataSource: HBOMaxLinksRemoteDataSourceContract
    private let localDataSource: CharactersLocalDataSourceContract
    private let mapper: CharacterEntityMapperContract
    private let detailMapper: CharacterDetailEntityMapperContract
    private let linksMapper: HBOMaxLinksMapperContract

    init(remoteDataSource: CharactersRemoteDataSourceContract,
         hboMaxLinksRemoteDataSource: HBOMaxLinksRemoteDataSourceContract,
         localDataSource: CharactersLocalDataSourceContract,
         mapper: CharacterEntityMapperContract,
         detailMapper: CharacterDetailEntityMapperContract,
         linksMapper: HBOMaxLinksMapperContract) {
        self.remoteDataSource = remoteDataSource
        self.hboMaxLinksRemoteDataSource = hboMaxLinksRemoteDataSource
        self.localDataSource = localDataSource
        self.mapper = mapper
        self.detailMapper = detailMapper
        self.linksMapper = linksMapper
    }

    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage {
        let query = CharactersQuery(filter: filter, page: page)

        let fetched = try await fetchThroughCache(
            label: "characters page \(page)",
            cached: { try await localDataSource.charactersPage(for: query) },
            fetch: { try await remoteDataSource.fetchCharactersPage(query) },
            store: { try await localDataSource.store($0, for: query) }
        )

        return map(fetched)
    }

    /// Unlike the list, an unmappable detail throws rather than being skipped — there is
    /// no rest of the page to fall back to.
    func fetchCharacterDetail(id: String) async throws -> CharacterDetailModel {
        let query = CharacterDetailQuery(id: id)

        let fetched = try await fetchThroughCache(
            label: "character detail \(id)",
            cached: { try await localDataSource.characterDetail(for: query) },
            fetch: { try await remoteDataSource.fetchCharacterDetail(query) },
            store: { try await localDataSource.store($0, for: query) }
        )

        return try detailMapper.map(fetched)
    }

    /// Fetches all episodes' offers in one request rather than per episode; mapping
    /// happens on every read since the cache stores the raw entity.
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

    /// The shared cache-then-network policy used by all three fetches above: fresh
    /// cache wins outright, a failed fetch falls back to a stale entry, cancellation
    /// always propagates.
    private func fetchThroughCache<Value: Sendable>(
        label: String,
        cached: () async throws -> CacheEntry<Value>?,
        fetch: () async throws -> Value,
        store: (Value) async throws -> Void
    ) async throws -> Value {
        // An unreadable cache is a miss, not a failure.
        let entry = try? await cached()

        if let entry, !entry.isExpired {
            return entry.value
        }

        do {
            let fetched = try await fetch()
            do {
                try await store(fetched)
            } catch {
                // Cache write failing does not fail the request.
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

    /// A character that fails to map is logged and skipped rather than failing the page.
    private func map(_ page: CharactersPageEntity) -> CharactersPage {
        let characters = page.results.compactMap { entity -> CharacterModel? in
            do {
                return try mapper.map(entity)
            } catch {
                print("[ERROR] \(error.localizedDescription)")
                return nil
            }
        }
        return CharactersPage(characters: characters, nextPage: page.info.next)
    }
}
