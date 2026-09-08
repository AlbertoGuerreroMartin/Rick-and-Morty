//
//  LocationsDependencies.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Networking
import Storage

/// What the Locations feature needs from the outside world; the app's container conforms to
/// this and hands it to `LocationsFactory`.
public protocol LocationsDependencies: Sendable {
    var graphQLClient: GraphQLClient { get }

    /// Shared across features: the store namespaces its entries, so one instance backs the whole app.
    var cacheStore: any CacheStoreContract { get }
}
