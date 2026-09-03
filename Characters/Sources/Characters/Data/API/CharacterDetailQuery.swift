//
//  CharacterDetailQuery.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import Networking

struct CharacterDetailQuery: GraphQLQuery {
    typealias ResponseEntity = CharacterDetailEntity
    
    static var objectRequested: String { "character" }
    
    let id: String
}
