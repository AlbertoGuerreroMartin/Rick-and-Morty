//
//  StubLocationsRemoteDataSource.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
@testable import Locations

/// Keyed on page number: the repository builds the query privately, so page is the only handle a test has.
actor StubLocationsRemoteDataSource: LocationsRemoteDataSourceContract {
    private let pages: [Int: Result<LocationsPageEntity, any Error>]
    private(set) var requestedPages: [Int] = []

    var callCount: Int { requestedPages.count }

    init(pages: [Int: Result<LocationsPageEntity, any Error>]) {
        self.pages = pages
    }

    func fetchLocationsPage(_ query: LocationsQuery) async throws -> LocationsPageEntity {
        let page = query.page ?? 1
        requestedPages.append(page)
        guard let result = pages[page] else { throw TestError() }
        return try result.get()
    }
}
