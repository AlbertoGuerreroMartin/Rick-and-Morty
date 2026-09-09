//
//  RickMortyApp.swift
//  RickMorty
//
//  Created by Alberto Guerrero Martin on 27/08/2026.
//

import Characters
import Episodes
import Locations
import SwiftUI

#if DEBUG
import DevTools
#endif

@main
struct RickMortyApp: App {
    /// Built once for the app's lifetime; features receive it and build their own layers from it.
    private let container = AppContainer()

    /// Built once, same reason as `container`: a fresh one per body evaluation would be a new
    /// object behind every push. See `RickMortyExternalNavigator`.
    private let externalNavigator: RickMortyExternalNavigator

    init() {
        externalNavigator = RickMortyExternalNavigator(container: container)
        container.sweepExpiredCache()
    }

    var body: some Scene {
        WindowGroup {
            tabs
        }
    }

    private var tabs: some View {
        let tabs = TabView {
            Tab("Characters", systemImage: "person") {
                // The navigator is registered by the assembly, not built here: a deep link must
                // reach it before the screen exists.
                CharactersFactory.build(root: container.root)
            }

            Tab("Episodes", systemImage: "list.bullet") {
                EpisodesFactory.build(root: container.root, external: externalNavigator)
            }

            Tab("Locations", systemImage: "mappin") {
                LocationsFactory.build(root: container.root, external: externalNavigator)
            }
        }

        // Debug only: `UIWindow.motionEnded` override is behind `#if DEBUG` too, so a shipped
        // build carries no swizzle. Shake the device (⌃⌘Z in the simulator) to open it.
        #if DEBUG
        return tabs.devToolsOnShake(caches: container.devToolsCaches,
                                    apiLog: container.apiLogStore,
                                    cacheLog: container.cacheLogStore)
        #else
        return tabs
        #endif
    }
}
