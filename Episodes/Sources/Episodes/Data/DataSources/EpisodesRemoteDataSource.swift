//
//  EpisodesRemoteDataSource.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking

/// Speaks entities, not domain models, so the repository maps on every read, network or disk.
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
