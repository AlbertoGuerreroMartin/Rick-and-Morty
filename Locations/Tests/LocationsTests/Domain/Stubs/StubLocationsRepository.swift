//
//  StubLocationsRepository.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
@testable import Locations

actor StubLocationsRepository: LocationsRepositoryContract {
    private let pages: [Int: Result<LocationsPage, any Error>]
    private(set) var requestedPages: [Int] = []

    init(pages: [Int: Result<LocationsPage, any Error>] = [:]) {
        self.pages = pages
    }

    func fetchLocations(page: Int) async throws -> LocationsPage {
        requestedPages.append(page)
        guard let result = pages[page] else { throw TestError() }
        return try result.get()
    }
}
