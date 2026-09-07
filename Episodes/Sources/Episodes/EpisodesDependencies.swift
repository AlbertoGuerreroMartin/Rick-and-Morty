//
//  EpisodesDependencies.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking
import Storage

/// What the Episodes feature needs from the outside world.
///
/// The composition root (the app) conforms its container to this protocol and
/// hands it to `EpisodesFactory`; the feature never reaches for shared
/// singletons itself. Adding a requirement here is a compile error in the app
/// until the container provides it, which keeps the wiring honest without a
/// runtime registry.
public protocol EpisodesDependencies: Sendable {
    var graphQLClient: GraphQLClient { get }

    /// A second client, because this feature talks to a second service: the
    /// "Watch on HBO Max" links come from JustWatch, at a different endpoint.
    ///
    /// It is a separate requirement rather than something the feature builds for
    /// itself, so the app stays the only place that decides what a network client
    /// is — same session policy, and above all the *same logger*, which is what
    /// puts a JustWatch request in the API log and the request inspector next to
    /// the episode pages instead of leaving it invisible.
    var justWatchClient: GraphQLClient { get }

    /// Shared with every other feature on purpose: the store namespaces its
    /// entries, so one instance backing the whole app means one directory, one
    /// expiry sweep and one place to reason about disk usage — rather than each
    /// feature growing its own cache with its own lifetime rules.
    var cacheStore: any CacheStoreContract { get }
}
