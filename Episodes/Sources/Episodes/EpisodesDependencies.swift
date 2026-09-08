//
//  EpisodesDependencies.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking
import Storage

public protocol EpisodesDependencies: Sendable {
    var graphQLClient: GraphQLClient { get }

    /// Separate client: "Watch on HBO Max" links come from JustWatch, a different endpoint.
    var justWatchClient: GraphQLClient { get }

    /// Shared across features so entries live in one directory under one expiry sweep.
    var cacheStore: any CacheStoreContract { get }
}
