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
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Characters", systemImage: "person") {
                    CharactersView()
                }

                Tab("Episodes", systemImage: "list.bullet") {
                    EpisodesView()
                }

                Tab("Locations", systemImage: "mappin") {
                    LocationsView()
                }
            }
        }
    }
}
