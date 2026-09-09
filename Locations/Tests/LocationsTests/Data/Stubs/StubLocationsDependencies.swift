//
//  StubLocationsDependencies.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
import Networking
import Storage
@testable import Locations

/// Stands in for the app container; nothing here reaches the network.
struct StubLocationsDependencies: LocationsDependencies {
    let graphQLClient = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!)
    let cacheStore: any CacheStoreContract

    init(root: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)) {
        cacheStore = CodableCacheStore(diskStore: FileDiskStore(root: root))
    }
}
