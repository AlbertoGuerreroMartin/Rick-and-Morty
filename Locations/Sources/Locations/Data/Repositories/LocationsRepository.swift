//
//  LocationsRepository.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation
import Storage

protocol LocationsRepositoryContract: Sendable {
    /// One page of the list. There is no filter parameter because this screen
    /// has no search: the page number is the whole request.
    func fetchLocations(page: Int) async throws -> LocationsPage
}

/// Decides, per page, whether the answer comes from disk or from the network.
///
/// The reason this coordination exists at all is the API's rate limit:
/// rickandmortyapi answers **429** once a client has made too many requests in a
/// short window, and a screen that refetches on every appearance walks into that
/// quickly — during development most of all, where the same tab is opened dozens
/// of times a minute. Cached pages turn all of those into zero requests.
///
/// The order of the four steps below is the whole policy:
///
/// 1. Read the cache, but never let a cache failure fail the request. A cache is
///    an optimisation; if it is broken the app should be slower, not broken.
/// 2. Fresh entry wins outright — no network at all.
/// 3. Otherwise go to the network and write what comes back. The write is also
///    best-effort: a full disk must not turn a successful fetch into an error.
/// 4. If the network fails and a *stale* entry exists, serve it. A throttled or
///    offline fetch still renders last week's locations, which is what the user
///    wants and what an empty error screen fails to give them. Cancellation is
///    the one exception — it means the screen went away, not that the fetch
///    failed, and swallowing it would defeat structured concurrency.
///
/// It lives in `fetchThroughCache(label:cached:fetch:store:)` even though this
/// feature has exactly one thing to fetch. That is not premature: the shape is
/// the one every other repository in the app uses, so a change to the policy is
/// a change to one recognisable helper in each of them rather than to four lines
/// inlined somewhere different every time.
final class LocationsRepository: LocationsRepositoryContract {
    private let remoteDataSource: LocationsRemoteDataSourceContract
    private let localDataSource: LocationsLocalDataSourceContract
    private let mapper: LocationEntityMapperContract

    init(remoteDataSource: LocationsRemoteDataSourceContract,
         localDataSource: LocationsLocalDataSourceContract,
         mapper: LocationEntityMapperContract) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
        self.mapper = mapper
    }

    func fetchLocations(page: Int) async throws -> LocationsPage {
        // Building the query here — and only here — is what keeps the cache
        // honest: the key is derived from the query, so each page addresses its
        // own entry without a single extra line in the local data source.
        let query = LocationsQuery(page: page)

        let fetched = try await fetchThroughCache(
            label: "locations page \(page)",
            cached: { try await localDataSource.locationsPage(for: query) },
            fetch: { try await remoteDataSource.fetchLocationsPage(query) },
            store: { try await localDataSource.store($0, for: query) }
        )

        return map(fetched)
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
    /// logged and skipped rather than failing the page: one nameless location
    /// should not blank twenty circles.
    private func map(_ page: LocationsPageEntity) -> LocationsPage {
        let locations = page.results.compactMap { entity -> LocationModel? in
            do {
                return try mapper.map(entity)
            } catch {
                // Log error without stopping the whole parsing process.
                print("[ERROR] \(error.localizedDescription)")
                return nil
            }
        }
        return LocationsPage(locations: locations, nextPage: page.info.next)
    }
}
