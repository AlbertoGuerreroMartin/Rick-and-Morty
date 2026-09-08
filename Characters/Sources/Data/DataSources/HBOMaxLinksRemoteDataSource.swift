//
//  HBOMaxLinksRemoteDataSource.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking

/// The JustWatch half of the network layer. Like `CharactersRemoteDataSource`,
/// it speaks *entities*: the repository stores the raw server shape and maps it
/// on every read, from disk and from the network through one code path.
///
/// A data source of its own rather than a third method on the characters one,
/// because it is a different service on a different endpoint with a different
/// client — and because a fake for it in a test then has nothing to do with
/// characters at all.
///
/// The Characters copy of the Episodes data source; see
/// `JustWatchShowOffersQuery` for why the pipeline is duplicated rather than
/// shared between two independent feature packages.
protocol HBOMaxLinksRemoteDataSourceContract: Sendable {
    func fetchShowOffers(_ query: JustWatchShowOffersQuery) async throws -> JustWatchShowEntity
}

final class HBOMaxLinksRemoteDataSource: HBOMaxLinksRemoteDataSourceContract {
    private let client: GraphQLClient

    /// - Parameter client: pointed at JustWatch, not at rickandmortyapi. Handing
    ///   in the wrong one is the single mistake this type can make, which is why
    ///   it is wired in exactly one place — `CharacterDetailFactory.makeGraph`.
    init(client: GraphQLClient) {
        self.client = client
    }

    func fetchShowOffers(_ query: JustWatchShowOffersQuery) async throws -> JustWatchShowEntity {
        try await client.execute(query).result
    }
}
