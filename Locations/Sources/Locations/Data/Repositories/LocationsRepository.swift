//
//  LocationsRepository.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation
import Storage

protocol LocationsRepositoryContract: Sendable {
    func fetchLocations(page: Int) async throws -> LocationsPage
}

/// Decides, per page, whether the answer comes from disk or the network — guarding against the
/// API's 429 rate limit. Policy: cache read failures are treated as a miss, never an error; a
/// fresh entry wins outright; otherwise fetch and best-effort store; if the fetch fails (except
/// on cancellation) and a stale entry exists, serve that instead of an error screen.
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
        let query = LocationsQuery(page: page)

        let fetched = try await fetchThroughCache(
            label: "locations page \(page)",
            cached: { try await localDataSource.locationsPage(for: query) },
            fetch: { try await remoteDataSource.fetchLocationsPage(query) },
            store: { try await localDataSource.store($0, for: query) }
        )

        return map(fetched)
    }

    /// `label` names the fetch in the store-failure log line only.
    private func fetchThroughCache<Value: Sendable>(
        label: String,
        cached: () async throws -> CacheEntry<Value>?,
        fetch: () async throws -> Value,
        store: (Value) async throws -> Void
    ) async throws -> Value {
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

    /// A location that fails to map is skipped, not fatal to the whole page.
    private func map(_ page: LocationsPageEntity) -> LocationsPage {
        let locations = page.results.compactMap { entity -> LocationModel? in
            do {
                return try mapper.map(entity)
            } catch {
                print("[ERROR] \(error.localizedDescription)")
                return nil
            }
        }
        return LocationsPage(locations: locations, nextPage: page.info.next)
    }
}
