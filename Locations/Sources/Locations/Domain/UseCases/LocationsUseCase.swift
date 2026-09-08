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

/// A pass-through, today.
///
/// It exists because it is the seam the view model is bound to: the presentation
/// layer names a use case and never a repository, so the day this screen needs
/// two answers to produce one — residents joined to their characters, say — the
/// join lands here and nothing above it changes. Deleting it now and adding it
/// back then would mean re-pointing the view model, the factory and every test
/// that stands one up, to save one file that does exactly what its name says.
final class LocationsUseCase: LocationsUseCaseContract {
    let repository: LocationsRepositoryContract

    init(repository: LocationsRepositoryContract) {
        self.repository = repository
    }

    func fetchLocations(page: Int) async throws -> LocationsPage {
        try await repository.fetchLocations(page: page)
    }
}
