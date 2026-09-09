//
//  StubCharactersDependencies.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
import Networking
import Storage
@testable import Characters

/// Stands in for the app container; nothing here reaches the network.
struct StubCharactersDependencies: CharactersDependencies {
    let graphQLClient = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!)
    let justWatchClient = GraphQLClient(endpoint: URL(string: "https://example.com/justwatch")!)
    let cacheStore: any CacheStoreContract = CodableCacheStore(
        diskStore: FileDiskStore(
            root: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
    )
}
