//
//  StubCharactersLocalDataSource.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
import Storage
@testable import Characters

actor StubCharactersLocalDataSource: CharactersLocalDataSourceContract {
    private let entry: CacheEntry<CharactersPageEntity>?
    private let detailEntry: CacheEntry<CharacterDetailEntity>?
    /// One offers entry, unkeyed: the lookup is one request for the whole show.
    private let offersEntry: CacheEntry<JustWatchShowEntity>?
    private let readError: (any Error)?
    private let writeError: (any Error)?
    private(set) var storedPages: [CharactersPageEntity] = []
    private(set) var storedDetails: [CharacterDetailEntity] = []
    private(set) var storedOffers: [JustWatchShowEntity] = []
    private(set) var removeAllCallCount = 0

    init(entry: CacheEntry<CharactersPageEntity>? = nil,
         detailEntry: CacheEntry<CharacterDetailEntity>? = nil,
         offersEntry: CacheEntry<JustWatchShowEntity>? = nil,
         readError: (any Error)? = nil,
         writeError: (any Error)? = nil) {
        self.entry = entry
        self.detailEntry = detailEntry
        self.offersEntry = offersEntry
        self.readError = readError
        self.writeError = writeError
    }

    func charactersPage(for query: CharactersQuery) async throws -> CacheEntry<CharactersPageEntity>? {
        if let readError { throw readError }
        return entry
    }

    func store(_ page: CharactersPageEntity, for query: CharactersQuery) async throws {
        if let writeError { throw writeError }
        storedPages.append(page)
    }

    func characterDetail(for query: CharacterDetailQuery) async throws -> CacheEntry<CharacterDetailEntity>? {
        if let readError { throw readError }
        return detailEntry
    }

    func store(_ detail: CharacterDetailEntity, for query: CharacterDetailQuery) async throws {
        if let writeError { throw writeError }
        storedDetails.append(detail)
    }

    func showOffers(for query: JustWatchShowOffersQuery) async throws -> CacheEntry<JustWatchShowEntity>? {
        if let readError { throw readError }
        return offersEntry
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
