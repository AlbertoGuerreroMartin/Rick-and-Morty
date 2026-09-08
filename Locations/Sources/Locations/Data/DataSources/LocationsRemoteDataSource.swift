//
//  LocationsRemoteDataSource.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Networking

/// The network half of the data layer. Returns entities, not domain models, so the
/// repository maps network and disk reads through one code path.
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
