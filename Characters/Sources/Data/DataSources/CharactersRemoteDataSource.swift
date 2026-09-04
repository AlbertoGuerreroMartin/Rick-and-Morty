//
//  CharactersRemoteDataSource.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Networking

protocol CharactersRemoteDataSourceContract: Sendable {
    func fetchCharacters() async throws -> [CharacterModel]
    func fetchCharacterDetail(characterId: String) async throws -> CharacterDetailModel
}

final class CharactersRemoteDataSource: CharactersRemoteDataSourceContract {
    private let client: GraphQLClient
    private let mapper: CharacterEntityMapperContract

    init(client: GraphQLClient,
         mapper: CharacterEntityMapperContract) {
        self.client = client
        self.mapper = mapper
    }
    
    func fetchCharacters() async throws -> [CharacterModel] {
        let query = CharactersQuery()
        return try await client.execute(query)
            .result.results.compactMap {
                do {
                    return try mapper.map($0)
                } catch {
                    // Log error without stopping the whole parsing process.
                    print("[ERROR] \(error.localizedDescription)")
                    return nil
                }
            }
    }
    
    func fetchCharacterDetail(characterId: String) async throws -> CharacterDetailModel {
        CharacterDetailModel(id: "", name: "", status: nil, species: nil, image: nil, origin: nil, location: nil, episode: [])
    }
    
    
}
