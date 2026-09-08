//
//  CharactersLocalDataSource.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation
import Networking
import Storage

/// The disk half of the data layer, mirroring ``CharactersRemoteDataSourceContract``
/// one method for one method so the repository can treat them as two answers to
/// the same question.
///
/// It hands back a `CacheEntry` rather than a bare value: whether a stale page
/// is better than an error screen is a decision only the repository can make,
/// and it needs `isExpired` to make it.
protocol CharactersLocalDataSourceContract: Sendable {
    func charactersPage(for query: CharactersQuery) async throws -> CacheEntry<CharactersPageEntity>?
    func store(_ page: CharactersPageEntity, for query: CharactersQuery) async throws
    func characterDetail(for query: CharacterDetailQuery) async throws -> CacheEntry<CharacterDetailEntity>?
    func store(_ detail: CharacterDetailEntity, for query: CharacterDetailQuery) async throws
    /// JustWatch's offer tree for the show, cached in this feature's namespace
    /// like everything else it reads — same `CacheEntry`, so the repository
    /// keeps the stale-while-error decision.
    ///
    /// It is the one thing here that does *not* keep the 24 h lifetime: see
    /// ``CharactersLocalDataSource/offersLifetime``.
    func showOffers(for query: JustWatchShowOffersQuery) async throws -> CacheEntry<JustWatchShowEntity>?
    func store(_ offers: JustWatchShowEntity, for query: JustWatchShowOffersQuery) async throws
    /// Drops everything this feature has cached — pages, details and offers alike.
    func removeAll() async throws
}

final class CharactersLocalDataSource: CharactersLocalDataSourceContract {

    /// How long a cached response stays fresh.
    ///
    /// A day, because the Rick and Morty catalogue is finished fiction: the
    /// episodes aired, the characters are not going to change species overnight.
    /// The number is a trade between two costs, and both point the same way here
    /// — a stale name is invisible to the user, while a refetch on every launch
    /// spends one of a small budget of requests before the API starts answering
    /// 429.
    static let lifetime: TimeInterval = 24 * 60 * 60

    /// How long the JustWatch offers stay fresh — a week, where everything else
    /// here settles for a day.
    ///
    /// The difference is not a preference, it is the data. Which episodes are on
    /// HBO Max changes when a licensing deal does, which is a matter of months,
    /// and the cost of being a few days out of date is a play button that opens
    /// an episode the service no longer carries. Against that, the lookup is a
    /// ~120 KB response from an unofficial third-party endpoint, fetched to draw
    /// a column of buttons — the least deserving request in the app of being
    /// repeated every morning. The character detail keeps its 24 h because it is
    /// the screen itself.
    static let offersLifetime: TimeInterval = 7 * 24 * 60 * 60

    /// One directory on disk for everything this feature caches, so the whole
    /// feature can be measured or wiped without enumerating its keys.
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

    // Two lines each, and no key string in sight: the generic plumbing below
    // derives the key from the query, so a third cached endpoint costs the same
    // as the first one did. The only thing this pair spells out is the lifetime,
    // because it is the one that differs.

    func showOffers(for query: JustWatchShowOffersQuery) async throws -> CacheEntry<JustWatchShowEntity>? {
        try await entry(for: query, as: JustWatchShowEntity.self)
    }

    func store(_ offers: JustWatchShowEntity, for query: JustWatchShowOffersQuery) async throws {
        try await storeValue(offers, for: query, lifetime: Self.offersLifetime)
    }

    /// The namespace is what makes this one call rather than a walk over every
    /// query the feature has ever made.
    func removeAll() async throws {
        try await cacheStore.removeAll(in: Self.namespace)
    }

    // MARK: - Generic plumbing

    // These two are the point of the whole type. Every cached query — paginated
    // or not, filtered or not, existing or not yet written — reduces to a key
    // derived from the query itself, so adding a cached endpoint is a two-line
    // method above and nothing at all down here. No per-query key strings to
    // invent, keep unique, and forget to change when the query changes.

    private func entry<Query: GraphQLQuery, Value: Codable & Sendable>(
        for query: Query,
        as type: Value.Type
    ) async throws -> CacheEntry<Value>? {
        try await cacheStore.entry(for: key(for: query), as: type)
    }

    /// Named `storeValue` rather than `store`: an overload named `store` would
    /// lose resolution to the concrete `store(_:for:)` above at every call site,
    /// which is a silent infinite recursion rather than a compile error.
    ///
    /// - Parameter lifetime: defaulted so the two-line methods above stay two
    ///   lines. It is a parameter at all because the JustWatch offers are the one
    ///   thing here that is not this feature's own data and does not age the same
    ///   way — spelling the exception at its call site keeps the default true for
    ///   everything else.
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
