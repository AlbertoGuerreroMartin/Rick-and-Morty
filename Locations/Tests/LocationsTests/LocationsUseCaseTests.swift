//
//  LocationsUseCaseTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation
import Testing
@testable import Locations

/// The use case is a pass-through today, and these tests say exactly that: the
/// page asked for is the page requested, the answer comes back untouched, and a
/// failure is not swallowed on the way. They are short because the type is, and
/// they are worth having because the day this grows a join, the assertions that
/// break are the ones describing what it used to guarantee.
@Suite("LocationsUseCase")
struct LocationsUseCaseTests {

    @Test("fetchLocations forwards to the repository and returns its answer")
    func fetchForwards() async throws {
        let repository = FakeLocationsRepository(pages: [1: .success(.make(names: ["Earth"], nextPage: 2))])
        let useCase = LocationsUseCase(repository: repository)

        let page = try await useCase.fetchLocations(page: 1)

        #expect(page.locations.map(\.name) == ["Earth"])
        #expect(page.nextPage == 2)
        #expect(await repository.requestedPages == [1])
    }

    /// The page number is the whole request, so losing it would silently serve
    /// page 1 for every circle on the carousel.
    @Test("the page number reaches the repository")
    func thePageNumberIsForwarded() async throws {
        let repository = FakeLocationsRepository(pages: [
            1: .success(.make(names: ["Earth"], nextPage: 2)),
            4: .success(.make(names: ["Abadango"], nextPage: nil))
        ])
        let useCase = LocationsUseCase(repository: repository)

        _ = try await useCase.fetchLocations(page: 4)

        #expect(await repository.requestedPages == [4])
    }

    @Test("a repository failure reaches the caller")
    func fetchRethrows() async {
        let useCase = LocationsUseCase(repository: FakeLocationsRepository(pages: [1: .failure(TestError())]))

        await #expect(throws: TestError.self) {
            _ = try await useCase.fetchLocations(page: 1)
        }
    }
}

// MARK: - Test doubles

actor FakeLocationsRepository: LocationsRepositoryContract {
    private let pages: [Int: Result<LocationsPage, any Error>]
    private(set) var requestedPages: [Int] = []

    init(pages: [Int: Result<LocationsPage, any Error>]) {
        self.pages = pages
    }

    func fetchLocations(page: Int) async throws -> LocationsPage {
        requestedPages.append(page)
        guard let result = pages[page] else { throw TestError() }
        return try result.get()
    }
}

extension LocationsPage {
    static func make(names: [String], nextPage: Int?) -> LocationsPage {
        LocationsPage(locations: names.enumerated().map { index, name in
            LocationModel.make(id: "\(index + 1)", name: name)
        }, nextPage: nextPage)
    }
}
