//
//  LocationsRemoteDataSource.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Networking

/// The network half of the data layer. It speaks *entities*, not domain models.
///
/// Returning the entity rather than a mapped model is what lets the repository
/// store the raw server shape and map on every read — from the network and from
/// disk alike — through one code path.
protocol LocationsRemoteDataSourceContract: Sendable {
    func fetchLocationsPage(_ query: LocationsQuery) async throws -> LocationsPageEntity
}

final class LocationsRemoteDataSource: LocationsRemoteDataSourceContract {
    private let client: GraphQLClient

    init(client: GraphQLClient) {
        self.client = client
    }

    func fetchLocationsPage(_ query: LocationsQuery) async throws -> LocationsPageEntity {
        try await client.execute(query).result
    }
}
