//
//  CharactersQuery.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import Networking

enum CharactersQueryGender: String, Encodable {
    case female
    case male
    case genderless
    case unknown
}

enum CharactersQueryStatus: String, Encodable {
    case alive
    case dead
    case unknown
}

struct CharactersQuery: GraphQLPaginatedQuery {
    typealias ResponseEntity = CharacterEntity
    
    static var objectRequested: String { "characters" }

    let page: Int?
    let name: String?
    let status: CharactersQueryStatus?
    let species: String?
    let type: String?
    let gender: CharactersQueryGender?
    
    init(
        page: Int? = nil,
        name: String? = nil,
        status: CharactersQueryStatus? = nil,
        species: String? = nil,
        type: String? = nil,
        gender: CharactersQueryGender? = nil
    ) {
        self.page = page
        self.name = name
        self.status = status
        self.species = species
        self.type = type
        self.gender = gender
    }
}
