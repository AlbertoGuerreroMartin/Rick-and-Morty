//
//  AppContainer.swift
//  RickMorty
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Characters
import DesignSystem
import Episodes
import Foundation
import Networking
import Storage

#if DEBUG
import DevTools
#endif

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
    /// Every cache read goes through here. A second store rather than a channel
    /// on `apiLogStore`, because the two live in packages that cannot see each
    /// other — and because the console wants them in separate categories, see
    /// `ConsoleCacheLogger`.
    let cacheLogStore: CacheLogStore
    let graphQLClient: GraphQLClient
    /// The second endpoint the app talks to: JustWatch, for the "Watch on HBO
    /// Max" links on the episodes screen. It shares `apiLogStore` with the
    /// client above, so a third-party request shows up in the console and the
    /// request inspector rather than going out unseen.
    let justWatchClient: GraphQLClient

    /// One store for the whole app, app-lifetime like the client. Features get
    /// their own directory through the key's namespace, so sharing the instance
    /// costs them no isolation and buys a single expiry sweep and a single place
    /// to reason about what is on disk.
    let cacheStore: any CacheStoreContract

    init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "RickMorty"
        #if DEBUG
        apiLogStore = APILogStore(sinks: [ConsoleAPILogger(subsystem: subsystem)])
        cacheLogStore = CacheLogStore(sinks: [ConsoleCacheLogger(subsystem: subsystem)])
        #else
        // The stores stay, the console sinks do not: a release build keeps the
        // in-memory history (which nothing reads without the debug screen) and
        // prints nothing.
        apiLogStore = APILogStore()
        cacheLogStore = CacheLogStore()
        #endif
        graphQLClient = GraphQLClient.rickAndMorty(logger: apiLogStore)
        justWatchClient = GraphQLClient.justWatch(logger: apiLogStore)
        // Built here rather than as a property initializer because it needs the
        // log store, which is only ready inside `init`.
        cacheStore = CodableCacheStore(diskStore: FileDiskStore(), logger: cacheLogStore)
        // The loader is a shared static that exists before this container does,
        // so it is configured rather than constructed. Synchronous on purpose:
        // the first images are requested as soon as the first screen appears,
        // and an `await` here would let them load unlogged.
        ImageLoader.shared.setLoggers(network: apiLogStore, cache: cacheLogStore)
    }

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

extension AppContainer: EpisodesDependencies {}

#if DEBUG
extension AppContainer {
    /// What the developer-tools screen offers to clear.
    ///
    /// The list lives here because the container is the only place that knows
    /// every feature. Each feature keeps its cache namespace private and exposes
    /// a `purgeCache` on its factory instead, so adding a cache to the screen is
    /// one line here and no change at all in `DevTools`.
    var devToolsCaches: [DevToolsCache] {
        [
            .images(),
            DevToolsCache(name: "Characters") { try await CharactersFactory.purgeCache(dependencies: self) },
            DevToolsCache(name: "Episodes") { try await EpisodesFactory.purgeCache(dependencies: self) }
        ]
    }
}
#endif
