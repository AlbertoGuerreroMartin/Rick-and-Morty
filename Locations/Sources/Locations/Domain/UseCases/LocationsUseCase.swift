//
//  LocationsUseCase.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation

protocol LocationsUseCaseContract: Sendable {
    func fetchLocations(page: Int) async throws -> LocationsPage
}

/// A pass-through today; the seam where the view model binds, not the repository directly.
final class LocationsUseCase: LocationsUseCaseContract {
    let repository: LocationsRepositoryContract

    init(repository: LocationsRepositoryContract) {
        self.repository = repository
    }

    func fetchLocations(page: Int) async throws -> LocationsPage {
        try await repository.fetchLocations(page: page)
    }
}
