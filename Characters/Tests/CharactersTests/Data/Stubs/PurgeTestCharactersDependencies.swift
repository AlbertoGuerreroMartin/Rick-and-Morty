//
//  PurgeTestCharactersDependencies.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
import Networking
import Storage
@testable import Characters

/// Stands in for the app container; `purgeCache` never uses the GraphQL clients.
struct PurgeTestCharactersDependencies: CharactersDependencies {
    let graphQLClient = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!)
    let justWatchClient = GraphQLClient(endpoint: URL(string: "https://example.com/justwatch")!)
    let cacheStore: any CacheStoreContract

    init(root: URL) {
        cacheStore = CodableCacheStore(diskStore: FileDiskStore(root: root))
    }
}
