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
    /// Built once for the app's lifetime; features receive it and build their
    /// own layers from it. See `AppContainer`.
    private let container = AppContainer()

    init() {
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
                CharactersFactory.build(dependencies: container)
            }

            Tab("Episodes", systemImage: "list.bullet") {
                EpisodesFactory.build(dependencies: container)
            }

            Tab("Locations", systemImage: "mappin") {
                LocationsView()
            }
        }

        // Debug only. The `DevTools` product is linked in every configuration,
        // but its `UIWindow.motionEnded` override is compiled under `#if DEBUG`
        // too, so a shipped build carries no process-wide swizzle. Shake the
        // device — Device ▸ Shake (⌃⌘Z) in the simulator — to open it.
        #if DEBUG
        return tabs.devToolsOnShake(caches: container.devToolsCaches,
                                    apiLog: container.apiLogStore,
                                    cacheLog: container.cacheLogStore)
        #else
        return tabs
        #endif
    }
}
