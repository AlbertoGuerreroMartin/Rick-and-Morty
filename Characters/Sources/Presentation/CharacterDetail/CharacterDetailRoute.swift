//
//  CharacterDetailRoute.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

/// What a tap on a character row pushes: an id, and nothing else.
///
/// The obvious alternative is to carry the `CharacterModel` the row already
/// holds — it would draw the name and the picture with no wait at all. It is not
/// what this does, for two reasons. The list's model has five of the eleven
/// fields the detail shows, so the screen would still have to fetch, and it
/// would render *twice*: once with a partial character and again when the real
/// answer landed, which reads as a flicker rather than as progress. And a value
/// pushed onto a `NavigationPath` outlives the row it came from — a reload or a
/// filter change behind the detail would leave it showing a character the list
/// no longer has, with no way to notice.
///
/// An id fetches once, shows one spinner, and is the same request whether it
/// came from the list, the grid, or a link this app has not been given yet.
///
/// `Hashable` and `Sendable` because `navigationDestination(for:)` requires it:
/// the value *is* the identity of the pushed screen.
struct CharacterDetailRoute: Hashable, Sendable {
    let id: String
}
