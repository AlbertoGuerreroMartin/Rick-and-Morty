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
    func fetchCharacters() async throws -> [CharacterModel] {
        // TODO: Move to upper layers
        let query = CharactersQuery()
        return try await GraphQLClient.rickAndMorty.execute(query)
            .result.results?.compactMap {
                // TODO: move to custom entity mapper on Data layer, and parse properly
                guard let character = $0 else { return nil }
                return CharacterModel(id: character.id,
                                      name: character.name,
                                      status: character.status.rawValue,
                                      species: character.species,
                                      image: character.image,
                                      origin: character.origin?.dimension,
                                      location: character.location?.dimension)
        } ?? []
    }
    
    func fetchCharacterDetail(characterId: String) async throws -> CharacterDetailModel {
        CharacterDetailModel(id: "", name: "", status: nil, species: nil, image: nil, origin: nil, location: nil, episode: [])
    }
    
    
}
