//
//  CharactersRemoteDataSource.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Networking

/// The network half of the data layer. It speaks *entities*, not domain models.
///
/// Mapping used to live here, which meant the only thing the repository could
/// hand to the cache was an already-mapped domain model. Returning the entity
/// instead is what lets the repository store the raw server shape and map on
/// every read — from the network and from disk alike — through one code path.
protocol CharactersRemoteDataSourceContract: Sendable {
    func fetchCharactersPage(_ query: CharactersQuery) async throws -> CharactersPageEntity
    func fetchCharacterDetail(_ query: CharacterDetailQuery) async throws -> CharacterDetailEntity
}

final class CharactersRemoteDataSource: CharactersRemoteDataSourceContract {
    private let client: GraphQLClient

    init(client: GraphQLClient) {
        self.client = client
    }

    func fetchCharactersPage(_ query: CharactersQuery) async throws -> CharactersPageEntity {
        try await client.execute(query).result
    }

    func fetchCharacterDetail(_ query: CharacterDetailQuery) async throws -> CharacterDetailEntity {
        try await client.execute(query).result
    }
}
