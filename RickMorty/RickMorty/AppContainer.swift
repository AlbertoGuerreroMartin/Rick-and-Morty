//
//  AppContainer.swift
//  RickMorty
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Characters
import Networking

/// The app's composition root.
///
/// Owns the long-lived infrastructure (a `GraphQLClient` today) and satisfies
/// every feature's `*Dependencies` protocol through the extensions below. Each
/// feature declares what it needs as a protocol; conforming here is what wires
/// the app together, and a missing requirement is a compile error rather than a
/// runtime lookup failure.
///
/// Screen-scoped objects (view models, use cases, repositories) are *not* held
/// here: each feature builds them per screen and SwiftUI owns their lifetime.
struct AppContainer: Sendable {
    let graphQLClient = GraphQLClient.rickAndMorty
}

extension AppContainer: CharactersDependencies {}
