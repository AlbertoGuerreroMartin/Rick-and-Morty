//
//  StubEpisodesLocalDataSource.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
import Storage
@testable import Episodes

actor StubEpisodesLocalDataSource: EpisodesLocalDataSourceContract {
    private let entries: [Int: CacheEntry<EpisodesPageEntity>]
    /// Only ever one offers entry: the lookup is one request for the whole show.
    private let offers: CacheEntry<JustWatchShowEntity>?
    private let readError: (any Error)?
    private let writeError: (any Error)?
    private(set) var storedPages: [EpisodesPageEntity] = []
    private(set) var storedOffers: [JustWatchShowEntity] = []
    private(set) var removeAllCallCount = 0

    init(entries: [Int: CacheEntry<EpisodesPageEntity>] = [:],
         offers: CacheEntry<JustWatchShowEntity>? = nil,
         readError: (any Error)? = nil,
         writeError: (any Error)? = nil) {
        self.entries = entries
        self.offers = offers
        self.readError = readError
        self.writeError = writeError
    }

    func episodesPage(for query: EpisodesQuery) async throws -> CacheEntry<EpisodesPageEntity>? {
        if let readError { throw readError }
        return entries[query.page ?? 1]
    }

    func store(_ page: EpisodesPageEntity, for query: EpisodesQuery) async throws {
        if let writeError { throw writeError }
        storedPages.append(page)
    }

    func showOffers(for query: JustWatchShowOffersQuery) async throws -> CacheEntry<JustWatchShowEntity>? {
        if let readError { throw readError }
        return offers
    }

    func store(_ offers: JustWatchShowEntity, for query: JustWatchShowOffersQuery) async throws {
        if let writeError { throw writeError }
        storedOffers.append(offers)
    }

    func removeAll() async throws {
        if let writeError { throw writeError }
        removeAllCallCount += 1
    }
}
