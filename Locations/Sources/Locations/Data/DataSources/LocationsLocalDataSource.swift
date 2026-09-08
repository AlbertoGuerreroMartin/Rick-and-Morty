//
//  LocationsLocalDataSource.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation
import Networking
import Storage

/// The disk half of the data layer, mirroring ``LocationsRemoteDataSourceContract``.
///
/// Returns a `CacheEntry`, not a bare value: only the repository decides whether a stale
/// page beats an error screen, and it needs `isExpired` to do that.
protocol LocationsLocalDataSourceContract: Sendable {
    func locationsPage(for query: LocationsQuery) async throws -> CacheEntry<LocationsPageEntity>?
    func store(_ page: LocationsPageEntity, for query: LocationsQuery) async throws
    func removeAll() async throws
}

final class LocationsLocalDataSource: LocationsLocalDataSourceContract {

    /// Seven days: this is finished fiction, so locations rarely change and a week-old
    /// cache costs nothing visible while saving a daily refetch of the same rows.
    static let lifetime: TimeInterval = 7 * 24 * 60 * 60

    /// One directory on disk for the whole feature, so it can be wiped without enumerating keys.
    private static let namespace = "locations"

    private let cacheStore: any CacheStoreContract

    init(cacheStore: any CacheStoreContract) {
        self.cacheStore = cacheStore
    }

    // MARK: - LocationsLocalDataSourceContract

    func locationsPage(for query: LocationsQuery) async throws -> CacheEntry<LocationsPageEntity>? {
        try await entry(for: query, as: LocationsPageEntity.self)
    }

    func store(_ page: LocationsPageEntity, for query: LocationsQuery) async throws {
        try await storeValue(page, for: query)
    }

    func removeAll() async throws {
        try await cacheStore.removeAll(in: Self.namespace)
    }

    // MARK: - Generic plumbing

    private func entry<Query: GraphQLQuery, Value: Codable & Sendable>(
        for query: Query,
        as type: Value.Type
    ) async throws -> CacheEntry<Value>? {
        try await cacheStore.entry(for: key(for: query), as: type)
    }

    /// Named `storeValue`, not `store`: an overload named `store` would recurse into itself
    /// instead of resolving to `store(_:for:)` above — a silent infinite loop, not a compile error.
    private func storeValue<Query: GraphQLQuery, Value: Codable & Sendable>(
        _ value: Value,
        for query: Query
    ) async throws {
        try await cacheStore.store(value, for: key(for: query), lifetime: Self.lifetime)
    }

    private func key<Query: GraphQLQuery>(for query: Query) -> CacheKey {
        CacheKey(namespace: Self.namespace, identifier: query.cacheIdentifier)
    }
}
