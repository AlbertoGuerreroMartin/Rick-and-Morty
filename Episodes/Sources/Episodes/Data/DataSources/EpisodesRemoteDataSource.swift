//
//  EpisodesRemoteDataSource.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking

/// The network half of the data layer. It speaks *entities*, not domain models.
///
/// Returning the entity rather than a mapped model is what lets the repository
/// store the raw server shape and map on every read — from the network and from
/// disk alike — through one code path.
protocol EpisodesRemoteDataSourceContract: Sendable {
    func fetchEpisodesPage(_ query: EpisodesQuery) async throws -> EpisodesPageEntity
}

final class EpisodesRemoteDataSource: EpisodesRemoteDataSourceContract {
    private let client: GraphQLClient

    init(client: GraphQLClient) {
        self.client = client
    }

    func fetchEpisodesPage(_ query: EpisodesQuery) async throws -> EpisodesPageEntity {
        try await client.execute(query).result
    }
}
