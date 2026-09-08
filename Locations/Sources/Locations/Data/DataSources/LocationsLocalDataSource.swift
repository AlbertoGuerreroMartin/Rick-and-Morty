//
//  LocationsLocalDataSource.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation
import Networking
import Storage

/// The disk half of the data layer, mirroring ``LocationsRemoteDataSourceContract``
/// one method for one method so the repository can treat them as two answers to
/// the same question.
///
/// It hands back a `CacheEntry` rather than a bare value: whether a stale page
/// is better than an error screen is a decision only the repository can make,
/// and it needs `isExpired` to make it.
protocol LocationsLocalDataSourceContract: Sendable {
    func locationsPage(for query: LocationsQuery) async throws -> CacheEntry<LocationsPageEntity>?
    func store(_ page: LocationsPageEntity, for query: LocationsQuery) async throws
    /// Drops every page this feature has cached.
    func removeAll() async throws
}

final class LocationsLocalDataSource: LocationsLocalDataSourceContract {

    /// How long a cached page stays fresh.
    ///
    /// Seven days, the episodes' number rather than the characters' one, and for
    /// the same reason: this is finished fiction. The 126 locations of Rick and
    /// Morty were named the day their episode aired, and a day-old dimension
    /// string is invisible to the user while a refetch every morning is a
    /// request budget spent to be told the same rows.
    ///
    /// The policy is applied **per page**, so an expiry here costs one request
    /// and not a walk — which is what makes a week comfortable rather than
    /// merely cheap. A week is still short enough that a new location appearing
    /// on the API shows up without the user doing anything.
    static let lifetime: TimeInterval = 7 * 24 * 60 * 60

    /// One directory on disk for everything this feature caches, so the whole
    /// feature can be measured or wiped without enumerating its keys.
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

    /// The namespace is what makes this one call rather than a walk over every
    /// query the feature has ever made.
    func removeAll() async throws {
        try await cacheStore.removeAll(in: Self.namespace)
    }

    // MARK: - Generic plumbing

    // The same two generics every other feature's local data source has. They
    // are what keep the methods above two lines long and free of key strings:
    // every cached query — paginated or not, existing or not yet written —
    // reduces to a key derived from the query itself, so adding a cached
    // endpoint costs a method up there and nothing at all down here.

    private func entry<Query: GraphQLQuery, Value: Codable & Sendable>(
        for query: Query,
        as type: Value.Type
    ) async throws -> CacheEntry<Value>? {
        try await cacheStore.entry(for: key(for: query), as: type)
    }

    /// Named `storeValue` rather than `store`: an overload named `store` would
    /// lose resolution to the concrete `store(_:for:)` above at every call site,
    /// which is a silent infinite recursion rather than a compile error.
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
