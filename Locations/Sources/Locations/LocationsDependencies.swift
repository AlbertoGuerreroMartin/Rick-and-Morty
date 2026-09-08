//
//  LocationsDependencies.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Networking
import Storage

/// What the Locations feature needs from the outside world.
///
/// The composition root (the app) conforms its container to this protocol and
/// hands it to `LocationsFactory`; the feature never reaches for shared
/// singletons itself. Adding a requirement here is a compile error in the app
/// until the container provides it, which keeps the wiring honest without a
/// runtime registry.
///
/// Two requirements, not three: this feature talks to one service. There is no
/// `justWatchClient` here because there is nothing to watch — a location has no
/// broadcast, so the second endpoint the episodes and character screens declare
/// would be a dependency this feature could never use.
public protocol LocationsDependencies: Sendable {
    var graphQLClient: GraphQLClient { get }

    /// Shared with every other feature on purpose: the store namespaces its
    /// entries, so one instance backing the whole app means one directory, one
    /// expiry sweep and one place to reason about disk usage — rather than each
    /// feature growing its own cache with its own lifetime rules.
    var cacheStore: any CacheStoreContract { get }
}
