//
//  CharactersDependencies.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Networking

/// What the Characters feature needs from the outside world.
///
/// The composition root (the app) conforms its container to this protocol and
/// hands it to `CharactersFactory`; the feature never reaches for shared
/// singletons itself. Adding a requirement here is a compile error in the app
/// until the container provides it, which keeps the wiring honest without a
/// runtime registry.
public protocol CharactersDependencies: Sendable {
    var graphQLClient: GraphQLClient { get }
}
