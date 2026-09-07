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
            TabView {
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
        }
    }
}
