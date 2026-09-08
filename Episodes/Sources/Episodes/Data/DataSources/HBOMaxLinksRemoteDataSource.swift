//
//  HBOMaxLinksRemoteDataSource.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking

/// Kept separate from `EpisodesRemoteDataSource`: a different service on a different endpoint.
protocol HBOMaxLinksRemoteDataSourceContract: Sendable {
    func fetchShowOffers(_ query: JustWatchShowOffersQuery) async throws -> JustWatchShowEntity
}

final class HBOMaxLinksRemoteDataSource: HBOMaxLinksRemoteDataSourceContract {
    private let client: GraphQLClient

    /// - Parameter client: must be pointed at JustWatch, not rickandmortyapi.
    init(client: GraphQLClient) {
        self.client = client
    }

    func fetchShowOffers(_ query: JustWatchShowOffersQuery) async throws -> JustWatchShowEntity {
        try await client.execute(query).result
    }
}
