//
//  CharactersUseCase.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Foundation

protocol CharactersUseCaseContract: Sendable {
    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage
    func purgeCache() async throws
}

final class CharactersUseCase: CharactersUseCaseContract {
    let repository: CharactersRepositoryContract

    init(repository: CharactersRepositoryContract) {
        self.repository = repository
    }

    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage {
        try await repository.fetchCharacters(filter: filter, page: page)
    }

    func purgeCache() async throws {
        try await repository.purgeCache()
    }
}
