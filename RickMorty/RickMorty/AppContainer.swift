//
//  AppContainer.swift
//  RickMorty
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Characters
import Foundation
import Networking
import Storage

/// The app's composition root.
///
/// Owns the long-lived infrastructure (a `GraphQLClient` and the cache store)
/// and satisfies every feature's `*Dependencies` protocol through the extensions
/// below. Each feature declares what it needs as a protocol; conforming here is
/// what wires the app together, and a missing requirement is a compile error
/// rather than a runtime lookup failure.
///
/// Screen-scoped objects (view models, use cases, repositories) are *not* held
/// here: each feature builds them per screen and SwiftUI owns their lifetime.
struct AppContainer: Sendable {
    /// Every API request and response goes through here. The store keeps the
    /// history for a future developer-tools screen; the console logger is a
    /// sink on it, attached only in debug builds so release output stays quiet.
    let apiLogStore: APILogStore
    let graphQLClient: GraphQLClient

    init() {
        #if DEBUG
        apiLogStore = APILogStore(sinks: [
            ConsoleAPILogger(subsystem: Bundle.main.bundleIdentifier ?? "RickMorty")
        ])
        #else
        apiLogStore = APILogStore()
        #endif
        graphQLClient = GraphQLClient.rickAndMorty(logger: apiLogStore)
    }

    /// One store for the whole app, app-lifetime like the client. Features get
    /// their own directory through the key's namespace, so sharing the instance
    /// costs them no isolation and buys a single expiry sweep and a single place
    /// to reason about what is on disk.
    let cacheStore: any CacheStoreContract = CodableCacheStore(diskStore: FileDiskStore())

    /// Drops entries whose lifetime has run out.
    ///
    /// Detached and at low priority because nothing on screen waits for it: the
    /// sweep only reclaims disk, and an expired entry is already handled
    /// correctly on read. Running it at launch — rather than on a timer or on
    /// every write — is what keeps a cache that is written far more often than
    /// it is swept from growing without bound across releases.
    func sweepExpiredCache() {
        Task.detached(priority: .background) { [cacheStore] in
            try? await cacheStore.removeExpired()
        }
    }
}

extension AppContainer: CharactersDependencies {}
