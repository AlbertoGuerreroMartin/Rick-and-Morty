//
//  CharactersRemoteDataSource.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Networking

/// The network half of the data layer. Returns entities, not domain models, so the repository
/// can cache the raw server shape and map on every read, from network and disk alike.
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
