//
//  LocationsUseCaseTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation
import Testing
@testable import Locations

@Suite("LocationsUseCase")
struct LocationsUseCaseTests {

    @Test("fetchLocations forwards to the repository and returns its answer")
    func fetchForwards() async throws {
        let repository = StubLocationsRepository(pages: [1: .success(.make(names: ["Earth"], nextPage: 2))])
        let useCase = LocationsUseCase(repository: repository)

        let page = try await useCase.fetchLocations(page: 1)

        #expect(page.locations.map(\.name) == ["Earth"])
        #expect(page.nextPage == 2)
        #expect(await repository.requestedPages == [1])
    }

    @Test("the page number reaches the repository")
    func thePageNumberIsForwarded() async throws {
        let repository = StubLocationsRepository(pages: [
            1: .success(.make(names: ["Earth"], nextPage: 2)),
            4: .success(.make(names: ["Abadango"], nextPage: nil))
        ])
        let useCase = LocationsUseCase(repository: repository)

        _ = try await useCase.fetchLocations(page: 4)

        #expect(await repository.requestedPages == [4])
    }

    @Test("a repository failure reaches the caller")
    func fetchRethrows() async {
        let useCase = LocationsUseCase(repository: StubLocationsRepository(pages: [1: .failure(TestError())]))

        await #expect(throws: TestError.self) {
            _ = try await useCase.fetchLocations(page: 1)
        }
    }
}

// MARK: - Test doubles

extension LocationsPage {
    static func make(names: [String], nextPage: Int?) -> LocationsPage {
        LocationsPage(locations: names.enumerated().map { index, name in
            LocationModel.make(id: "\(index + 1)", name: name)
        }, nextPage: nextPage)
    }
}
