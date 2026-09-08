//
//  CharactersPage.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

/// One page of characters, in domain terms. Carries `nextPage`, the only signal of whether there is more to load.
struct CharactersPage: Sendable {
    let characters: [CharacterModel]
    /// The page number to ask for next, or `nil` at the end of the list.
    let nextPage: Int?
}
