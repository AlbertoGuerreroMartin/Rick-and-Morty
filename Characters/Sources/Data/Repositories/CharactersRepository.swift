//
//  CharactersRepository.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Foundation

protocol CharactersRepositoryContract: Sendable {
    /// One page of the list *for a filter*. The filter is part of the request
    /// rather than state on the repository so that two screens — or two reloads
    /// racing each other — can never read each other's constraints.
    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage
}

/// Decides, per request, whether the answer comes from disk or from the network.
///
/// The reason this coordination exists at all is the API's rate limit: rickandmortyapi
/// answers **429** once a client has made too many requests in a short window,
/// and a list screen that refetches on every appearance walks into that quickly
/// — during development most of all, where the same screen is opened dozens of
/// times a minute. Cached pages turn all of those into zero requests.
///
/// The order of the four steps below is the whole policy:
///
/// 1. Read the cache, but never let a cache failure fail the request. A cache is
///    an optimisation; if it is broken the app should be slower, not broken.
/// 2. Fresh entry wins outright — no network at all.
/// 3. Otherwise go to the network and write what comes back. The write is also
///    best-effort: a full disk must not turn a successful fetch into an error.
/// 4. If the network fails and a *stale* entry exists, serve it. A throttled or
///    offline fetch still renders yesterday's characters, which is what the user
///    wants and what an empty error screen fails to give them. Cancellation is
///    the one exception — it means the screen went away, not that the fetch
///    failed, and swallowing it would defeat structured concurrency.
final class CharactersRepository: CharactersRepositoryContract {
    private let remoteDataSource: CharactersRemoteDataSourceContract
    private let localDataSource: CharactersLocalDataSourceContract
    private let mapper: CharacterEntityMapperContract

    init(remoteDataSource: CharactersRemoteDataSourceContract,
         localDataSource: CharactersLocalDataSourceContract,
         mapper: CharacterEntityMapperContract) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
        self.mapper = mapper
    }

    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage {
        // Building the query here — and only here — is what keeps the cache
        // honest: the key is derived from the query, so a filtered page and an
        // unfiltered one address different entries without a single extra line
        // in the local data source.
        let query = CharactersQuery(filter: filter, page: page)

        // `try?`: an unreadable cache is a miss, not a failure. Step 1.
        let cached = try? await localDataSource.charactersPage(for: query)

        if let cached, !cached.isExpired {
            return map(cached.value)
        }

        do {
            let fetched = try await remoteDataSource.fetchCharactersPage(query)
            do {
                try await localDataSource.store(fetched, for: query)
            } catch {
                // Step 3: the fetch succeeded, so the caller still gets its page.
                print("[ERROR] Could not cache characters page \(page): \(error.localizedDescription)")
            }
            return map(fetched)
        } catch let error as CancellationError {
            throw error
        } catch {
            guard let cached else { throw error }
            return map(cached.value)
        }
    }

    /// Mapping happens here, on every read, from disk and network alike — which
    /// is why the cache stores entities. A single entity that fails to map is
    /// logged and skipped rather than failing the page: one character missing a
    /// `name` should not blank the whole list.
    private func map(_ page: CharactersPageEntity) -> CharactersPage {
        let characters = page.results.compactMap { entity -> CharacterModel? in
            do {
                return try mapper.map(entity)
            } catch {
                // Log error without stopping the whole parsing process.
                print("[ERROR] \(error.localizedDescription)")
                return nil
            }
        }
        return CharactersPage(characters: characters, nextPage: page.info.next)
    }
}
