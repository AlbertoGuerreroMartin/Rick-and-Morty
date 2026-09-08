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
import Locations
import Networking
import Storage

#if DEBUG
import DevTools
#endif

/// The app's composition root. Wires long-lived infrastructure and satisfies every feature's
/// `*Dependencies` protocol; screen-scoped objects are built per screen instead, by each feature.
struct AppContainer: Sendable {
    /// Every API request/response log; console sink attached only in debug builds.
    let apiLogStore: APILogStore
    /// Every cache-read log. Separate from `apiLogStore`: different packages, and `ConsoleCacheLogger`
    /// wants its own category.
    let cacheLogStore: CacheLogStore
    let graphQLClient: GraphQLClient
    /// JustWatch endpoint, for the HBO Max links on the episodes screen. Shares `apiLogStore` so
    /// these requests show up in the inspector too.
    let justWatchClient: GraphQLClient

    /// One store for the whole app; features get separate directories via the cache key's namespace.
    let cacheStore: any CacheStoreContract

    /// Tab-root navigation stacks, held here rather than per-screen because a deep link must reach
    /// them before the screen it targets exists. One per tab, each with its own route type.
    let charactersNavigator = CharactersNavigator()
    let episodesNavigator = EpisodesNavigator()
    let locationsNavigator = LocationsNavigator()

    /// Main-actor: the navigators above are main-actor classes.
    @MainActor
    init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "RickMorty"
        #if DEBUG
        apiLogStore = APILogStore(sinks: [ConsoleAPILogger(subsystem: subsystem)])
        cacheLogStore = CacheLogStore(sinks: [ConsoleCacheLogger(subsystem: subsystem)])
        #else
        // Release builds keep the in-memory history but attach no console sink.
        apiLogStore = APILogStore()
        cacheLogStore = CacheLogStore()
        #endif
        graphQLClient = GraphQLClient.rickAndMorty(logger: apiLogStore)
        justWatchClient = GraphQLClient.justWatch(logger: apiLogStore)
        // Built here, not as a property initializer, since it needs the log store from `init`.
        cacheStore = CodableCacheStore(diskStore: FileDiskStore(), logger: cacheLogStore)
        // `ImageLoader.shared` is a pre-existing static, so it's configured rather than constructed.
        // Synchronous so the first images (requested as soon as the first screen appears) are logged.
        ImageLoader.shared.setLoggers(network: apiLogStore, cache: cacheLogStore)
    }

    /// Drops expired cache entries. Detached and low-priority: reads already handle expiry
    /// correctly, so this only reclaims disk space.
    func sweepExpiredCache() {
        Task.detached(priority: .background) { [cacheStore] in
            try? await cacheStore.removeExpired()
        }
    }
}

extension AppContainer: CharactersDependencies {}

extension AppContainer: EpisodesDependencies {}

extension AppContainer: LocationsDependencies {}

#if DEBUG
extension AppContainer {
    /// What the developer-tools screen can clear. Lives here since the container is the only
    /// place that knows every feature.
    var devToolsCaches: [DevToolsCache] {
        [
            .images(),
            DevToolsCache(name: "Characters") { try await CharactersFactory.purgeCache(dependencies: self) },
            DevToolsCache(name: "Episodes") { try await EpisodesFactory.purgeCache(dependencies: self) },
            DevToolsCache(name: "Locations") { try await LocationsFactory.purgeCache(dependencies: self) }
        ]
    }
}
#endif
