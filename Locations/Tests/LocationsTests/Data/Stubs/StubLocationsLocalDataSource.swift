//
//  StubLocationsLocalDataSource.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
import Storage
@testable import Locations

actor StubLocationsLocalDataSource: LocationsLocalDataSourceContract {
    private let entries: [Int: CacheEntry<LocationsPageEntity>]
    private let readError: (any Error)?
    private let writeError: (any Error)?
    private(set) var storedPages: [LocationsPageEntity] = []
    private(set) var removeAllCallCount = 0

    init(entries: [Int: CacheEntry<LocationsPageEntity>] = [:],
         readError: (any Error)? = nil,
         writeError: (any Error)? = nil) {
        self.entries = entries
        self.readError = readError
        self.writeError = writeError
    }

    func locationsPage(for query: LocationsQuery) async throws -> CacheEntry<LocationsPageEntity>? {
        if let readError { throw readError }
        return entries[query.page ?? 1]
    }

    func store(_ page: LocationsPageEntity, for query: LocationsQuery) async throws {
        if let writeError { throw writeError }
        storedPages.append(page)
    }

    func removeAll() async throws {
        if let writeError { throw writeError }
        removeAllCallCount += 1
    }
}
