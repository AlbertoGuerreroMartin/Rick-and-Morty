//
//  CharactersUseCase.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Foundation

protocol CharactersUseCaseContract: Sendable {
    func fetchCharacters() async throws -> [CharacterModel]
}

final class CharactersUseCase: CharactersUseCaseContract {
    let repository: CharactersRepositoryContract
    
    init(repository: CharactersRepositoryContract) {
        self.repository = repository
    }
    
    func fetchCharacters() async throws -> [CharacterModel] {
        // The list screen shows the first page only; paginating the UI is out of
        // scope. The cache is keyed per page already, so adding it later changes
        // this line and nothing below it.
        try await repository.fetchCharacters(page: 1).characters
    }
}
