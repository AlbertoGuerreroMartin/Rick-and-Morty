//
//  CharactersDependencies.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Networking
import Storage

/// What the Characters feature needs from the outside world.
///
/// The app conforms its container to this protocol and hands it to `CharactersFactory`;
/// adding a requirement here is a compile error until the container provides it.
public protocol CharactersDependencies: Sendable {
    var graphQLClient: GraphQLClient { get }

    /// Second client: the "Watch on HBO Max" links come from JustWatch, a different endpoint.
    var justWatchClient: GraphQLClient { get }

    /// Shared across features: one instance means one directory, one expiry sweep.
    var cacheStore: any CacheStoreContract { get }
}
