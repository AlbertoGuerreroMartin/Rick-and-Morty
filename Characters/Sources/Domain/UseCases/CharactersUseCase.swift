//
//  CharactersUseCase.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Foundation

protocol CharactersUseCaseContract: Sendable {
    func fetchCharacters(page: Int) async throws -> CharactersPage
}

final class CharactersUseCase: CharactersUseCaseContract {
    let repository: CharactersRepositoryContract

    init(repository: CharactersRepositoryContract) {
        self.repository = repository
    }

    func fetchCharacters(page: Int) async throws -> CharactersPage {
        try await repository.fetchCharacters(page: page)
    }
}
