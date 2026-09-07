//
//  EpisodeModel.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// One episode, in domain terms.
///
/// `code`, `season` and `number` all come out of the same string on the wire
/// (`S05E10`), and all three are kept rather than one being derived from the
/// others at the point of use. Each has a distinct job: `code` is what the row
/// *shows* and what the local search matches, so it is stored verbatim rather
/// than reformatted — the API's spelling is the one the user recognises from
/// anywhere else they have seen it. `season` and `number` are what the section
/// mapper groups and orders by, and parsing them there, on every keystroke,
/// would put a regex in the render path.
struct EpisodeModel: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    /// The air date exactly as the API words it, e.g. `December 2, 2013`.
    ///
    /// Kept as text rather than parsed into a `Date`: it has no time zone and no
    /// time of day, and every use of it in this feature is display or search.
    /// Parsing it would mean picking a locale to parse *in* and another to
    /// format back out, which is two chances to turn a correct date into a wrong
    /// one for no gain the user can see.
    let airDate: String
    /// The broadcast code as the API spells it, e.g. `S01E05`.
    let code: String
    let season: Int
    /// The episode's number *within its season*, from the code.
    let number: Int
    /// When the API's own record was created. Never shown; `nil` when the field
    /// was absent or unparseable, which is why it is optional and not required.
    let created: Date?
    let characters: [EpisodeCharacterModel]
}

/// A character as an episode row knows one: something to draw and something to
/// key it on.
///
/// The `id` is not used to draw anything today. It is kept because the avatar
/// strip is the obvious place for a tap to open a character, and a strip already
/// keyed on the id turns that into a one-line change rather than a trip back
/// through the entity, the mapper and the query.
struct EpisodeCharacterModel: Sendable, Hashable, Identifiable {
    let id: String
    let image: URL
}
