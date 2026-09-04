//
//  CharactersPage.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

/// One page of characters, in domain terms.
///
/// The repository returns this rather than a bare `[CharacterModel]` because
/// `nextPage` is the only thing that says whether there is more to load, and it
/// exists on the wire (`info.next`). Dropping it at the data layer would mean
/// re-deriving pagination from a count later, or a second request just to find
/// out there is nothing left.
struct CharactersPage: Sendable {
    let characters: [CharacterModel]
    /// The page number to ask for next, or `nil` at the end of the list.
    let nextPage: Int?
}
