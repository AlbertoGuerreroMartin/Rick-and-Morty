//
//  CharactersRepository.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Foundation

final class CharactersRepository: CharactersRepositoryContract {
    private let remoteDataSource: CharactersRemoteDataSourceContract
    
    init(remoteDataSource: CharactersRemoteDataSourceContract) {
        self.remoteDataSource = remoteDataSource
    }
    
    func fetchCharacters() async throws -> [CharacterModel] {
        try await remoteDataSource.fetchCharacters()
    }
}
