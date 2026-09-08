//
//  HBOMaxLinksRemoteDataSource.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking

/// The JustWatch half of the network layer. Separate from `CharactersRemoteDataSource` because
/// it's a different service, endpoint and client. See `JustWatchShowOffersQuery` for why the
/// pipeline duplicates the Episodes feature's copy rather than sharing it.
protocol HBOMaxLinksRemoteDataSourceContract: Sendable {
    func fetchShowOffers(_ query: JustWatchShowOffersQuery) async throws -> JustWatchShowEntity
}

final class HBOMaxLinksRemoteDataSource: HBOMaxLinksRemoteDataSourceContract {
    private let client: GraphQLClient

    /// - Parameter client: must point at JustWatch, not rickandmortyapi; wired only in
    ///   `CharacterDetailFactory.makeGraph`.
    init(client: GraphQLClient) {
        self.client = client
    }

    func fetchShowOffers(_ query: JustWatchShowOffersQuery) async throws -> JustWatchShowEntity {
        try await client.execute(query).result
    }
}
