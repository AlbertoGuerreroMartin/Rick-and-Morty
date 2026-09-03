//
//  CharactersRepositoryContract.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Foundation

protocol CharactersRepositoryContract: Sendable {
    func fetchCharacters() async throws -> [CharacterModel]
}
