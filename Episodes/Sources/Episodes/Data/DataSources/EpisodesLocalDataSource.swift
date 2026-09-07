//
//  EpisodesLocalDataSource.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Storage

/// The disk half of the data layer, mirroring ``EpisodesRemoteDataSourceContract``
/// one method for one method so the repository can treat them as two answers to
/// the same question.
///
/// It hands back a `CacheEntry` rather than a bare value: whether a stale page
/// is better than an error screen is a decision only the repository can make,
/// and it needs `isExpired` to make it.
protocol EpisodesLocalDataSourceContract: Sendable {
    func episodesPage(for query: EpisodesQuery) async throws -> CacheEntry<EpisodesPageEntity>?
    func store(_ page: EpisodesPageEntity, for query: EpisodesQuery) async throws
    /// Drops every page this feature has cached.
    func removeAll() async throws
}

final class EpisodesLocalDataSource: EpisodesLocalDataSourceContract {

    /// How long a cached page stays fresh.
    ///
    /// Seven days, where the characters list settles for one. The difference is
    /// not a preference, it is the data: the episode catalogue almost never
    /// changes — 51 episodes of finished television, with a name, an air date
    /// and a code that were fixed the day each one aired. A day-long lifetime
    /// would spend three requests every morning to be told the same 51 rows,
    /// and this screen fetches *every* page on load rather than one, so each
    /// expiry costs the whole walk. A week is still short enough that a new
    /// season appearing on the API shows up without the user doing anything.
    static let lifetime: TimeInterval = 7 * 24 * 60 * 60

    /// One directory on disk for everything this feature caches, so the whole
    /// feature can be measured or wiped without enumerating its keys.
    private static let namespace = "episodes"

    private let cacheStore: any CacheStoreContract

    init(cacheStore: any CacheStoreContract) {
        self.cacheStore = cacheStore
    }

    // MARK: - EpisodesLocalDataSourceContract

    func episodesPage(for query: EpisodesQuery) async throws -> CacheEntry<EpisodesPageEntity>? {
        try await entry(for: query, as: EpisodesPageEntity.self)
    }

    func store(_ page: EpisodesPageEntity, for query: EpisodesQuery) async throws {
        try await storeValue(page, for: query)
    }

    /// The namespace is what makes this one call rather than a walk over every
    /// query the feature has ever made.
    func removeAll() async throws {
        try await cacheStore.removeAll(in: Self.namespace)
    }

    // MARK: - Generic plumbing

    // These two are the point of the whole type. Every cached query — paginated
    // or not, existing or not yet written — reduces to a key derived from the
    // query itself, so adding a cached endpoint is a two-line method above and
    // nothing at all down here. No per-query key strings to invent, keep unique,
    // and forget to change when the query changes.

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
