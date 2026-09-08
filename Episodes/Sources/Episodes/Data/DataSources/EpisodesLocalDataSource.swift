//
//  EpisodesLocalDataSource.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Storage

/// Hands back a `CacheEntry`, not a bare value, so the repository can decide stale-vs-error.
protocol EpisodesLocalDataSourceContract: Sendable {
    func episodesPage(for query: EpisodesQuery) async throws -> CacheEntry<EpisodesPageEntity>?
    func store(_ page: EpisodesPageEntity, for query: EpisodesQuery) async throws
    func showOffers(for query: JustWatchShowOffersQuery) async throws -> CacheEntry<JustWatchShowEntity>?
    func store(_ offers: JustWatchShowEntity, for query: JustWatchShowOffersQuery) async throws
    func removeAll() async throws
}

final class EpisodesLocalDataSource: EpisodesLocalDataSourceContract {

    /// Seven days, not the characters list's one: the finished-TV catalogue almost never changes.
    static let lifetime: TimeInterval = 7 * 24 * 60 * 60

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

    func showOffers(for query: JustWatchShowOffersQuery) async throws -> CacheEntry<JustWatchShowEntity>? {
        try await entry(for: query, as: JustWatchShowEntity.self)
    }

    func store(_ offers: JustWatchShowEntity, for query: JustWatchShowOffersQuery) async throws {
        try await storeValue(offers, for: query)
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

    /// Named `storeValue`, not `store`: that name would resolve to `store(_:for:)` above at every
    /// call site, causing silent infinite recursion.
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
