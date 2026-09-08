//
//  CharactersRoute.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

/// Everything the Characters tab's stack can hold, as one closed set.
///
/// One enum per stack: `NavigationStack(path:)` binds to a single element type, so
/// `navigationDestination(for:)` switches exhaustively and a missing case is a build failure.
/// A case carries only an id, not the row's `CharacterModel`, since the list's model is
/// missing fields the detail needs and could go stale on the path.
enum CharactersRoute: Hashable, Sendable {
    case detail(id: String)
}
