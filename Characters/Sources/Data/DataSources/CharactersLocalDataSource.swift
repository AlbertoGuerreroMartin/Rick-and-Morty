//
//  CharactersLocalDataSource.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation
import Networking
import Storage

protocol CharactersLocalDataSourceContract: Sendable {
    func charactersPage(for query: CharactersQuery) async throws -> CacheEntry<CharactersPageEntity>?
    func store(_ page: CharactersPageEntity, for query: CharactersQuery) async throws
    func characterDetail(for query: CharacterDetailQuery) async throws -> CacheEntry<CharacterDetailEntity>?
    func store(_ detail: CharacterDetailEntity, for query: CharacterDetailQuery) async throws
    func showOffers(for query: JustWatchShowOffersQuery) async throws -> CacheEntry<JustWatchShowEntity>?
    func store(_ offers: JustWatchShowEntity, for query: JustWatchShowOffersQuery) async throws
    func removeAll() async throws
}

final class CharactersLocalDataSource: CharactersLocalDataSourceContract {

    /// A day: the catalogue is finished fiction and a stale name is cheap.
    static let lifetime: TimeInterval = 24 * 60 * 60

    /// A week: a ~120 KB third-party lookup, not worth refetching daily.
    static let offersLifetime: TimeInterval = 7 * 24 * 60 * 60

    private static let namespace = "characters"

    private let cacheStore: any CacheStoreContract

    init(cacheStore: any CacheStoreContract) {
        self.cacheStore = cacheStore
    }

    // MARK: - CharactersLocalDataSourceContract

    func charactersPage(for query: CharactersQuery) async throws -> CacheEntry<CharactersPageEntity>? {
        try await entry(for: query, as: CharactersPageEntity.self)
    }

    func store(_ page: CharactersPageEntity, for query: CharactersQuery) async throws {
        try await storeValue(page, for: query)
    }

    func characterDetail(for query: CharacterDetailQuery) async throws -> CacheEntry<CharacterDetailEntity>? {
        try await entry(for: query, as: CharacterDetailEntity.self)
    }

    func store(_ detail: CharacterDetailEntity, for query: CharacterDetailQuery) async throws {
        try await storeValue(detail, for: query)
    }

    func showOffers(for query: JustWatchShowOffersQuery) async throws -> CacheEntry<JustWatchShowEntity>? {
        try await entry(for: query, as: JustWatchShowEntity.self)
    }

    func store(_ offers: JustWatchShowEntity, for query: JustWatchShowOffersQuery) async throws {
        try await storeValue(offers, for: query, lifetime: Self.offersLifetime)
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

    /// Named `storeValue`: an overload named `store` would recurse into itself silently.
    private func storeValue<Query: GraphQLQuery, Value: Codable & Sendable>(
        _ value: Value,
        for query: Query,
        lifetime: TimeInterval = CharactersLocalDataSource.lifetime
    ) async throws {
        try await cacheStore.store(value, for: key(for: query), lifetime: lifetime)
    }

    private func key<Query: GraphQLQuery>(for query: Query) -> CacheKey {
        CacheKey(namespace: Self.namespace, identifier: query.cacheIdentifier)
    }
}
