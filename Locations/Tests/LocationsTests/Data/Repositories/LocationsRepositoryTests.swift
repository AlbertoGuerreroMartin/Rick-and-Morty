//
//  LocationsRepositoryTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation
import Networking
import Storage
import Testing
@testable import Locations

@Suite("LocationsRepository")
struct LocationsRepositoryTests {

    @Test("a fresh cache entry answers without touching the network")
    func freshCacheSkipsTheNetwork() async throws {
        let local = StubLocationsLocalDataSource(entries: [1: .fresh(page: .make(names: ["Earth"]))])
        let remote = StubLocationsRemoteDataSource(pages: [1: .success(.make(names: ["Abadango"]))])
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchLocations(page: 1)

        #expect(page.locations.map(\.name) == ["Earth"])
        #expect(await remote.callCount == 0)
    }

    @Test("an expired entry is refreshed from the network and written back")
    func expiredCacheRefetchesAndStores() async throws {
        let local = StubLocationsLocalDataSource(entries: [1: .expired(page: .make(names: ["Earth"]))])
        let remote = StubLocationsRemoteDataSource(pages: [1: .success(.make(names: ["Abadango"]))])
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchLocations(page: 1)

        #expect(page.locations.map(\.name) == ["Abadango"])
        #expect(await remote.callCount == 1)
        #expect(await local.storedPages.first?.results.first?.name == "Abadango")
    }

    @Test("a failed refresh falls back to the stale entry")
    func staleEntrySurvivesAFailedFetch() async throws {
        let local = StubLocationsLocalDataSource(entries: [1: .expired(page: .make(names: ["Earth"]))])
        let remote = StubLocationsRemoteDataSource(pages: [1: .failure(TestError())])
        let repository = makeRepository(remote: remote, local: local)

        #expect(try await repository.fetchLocations(page: 1).locations.map(\.name) == ["Earth"])
    }

    @Test("with nothing cached, a failed fetch is an error")
    func noCacheAndFailedFetchThrows() async {
        let repository = makeRepository(remote: StubLocationsRemoteDataSource(pages: [1: .failure(TestError())]),
                                        local: StubLocationsLocalDataSource())

        await #expect(throws: TestError.self) {
            _ = try await repository.fetchLocations(page: 1)
        }
    }

    @Test("a cache read that throws is a miss, not a failure")
    func cacheReadFailureFallsThroughToTheNetwork() async throws {
        let local = StubLocationsLocalDataSource(readError: TestError())
        let remote = StubLocationsRemoteDataSource(pages: [1: .success(.make(names: ["Earth"]))])
        let repository = makeRepository(remote: remote, local: local)

        #expect(try await repository.fetchLocations(page: 1).locations.map(\.name) == ["Earth"])
        #expect(await remote.callCount == 1)
    }

    @Test("a cache write that throws still returns the fetched page")
    func cacheWriteFailureDoesNotFailTheFetch() async throws {
        let local = StubLocationsLocalDataSource(writeError: TestError())
        let remote = StubLocationsRemoteDataSource(pages: [1: .success(.make(names: ["Earth"]))])
        let repository = makeRepository(remote: remote, local: local)

        #expect(try await repository.fetchLocations(page: 1).locations.map(\.name) == ["Earth"])
    }

    @Test("cancellation is rethrown rather than answered from a stale entry")
    func cancellationIsRethrown() async {
        let local = StubLocationsLocalDataSource(entries: [1: .expired(page: .make(names: ["Earth"]))])
        let remote = StubLocationsRemoteDataSource(pages: [1: .failure(CancellationError())])
        let repository = makeRepository(remote: remote, local: local)

        await #expect(throws: CancellationError.self) {
            _ = try await repository.fetchLocations(page: 1)
        }
    }

    // MARK: - Mapping

    @Test("one unmappable entity is skipped, not fatal to the page")
    func unmappableEntitiesAreSkipped() async throws {
        let broken = LocationEntity(id: nil, name: nil, type: nil, dimension: nil, residents: nil)
        let page = LocationsPageEntity(info: GraphQLPageInfo(count: 2, pages: 1, next: nil),
                                       results: [broken, .make(name: "Earth")])
        let local = StubLocationsLocalDataSource(entries: [1: .fresh(page: page)])
        let repository = makeRepository(remote: StubLocationsRemoteDataSource(pages: [:]), local: local)

        #expect(try await repository.fetchLocations(page: 1).locations.map(\.name) == ["Earth"])
    }

    @Test("a cached entity is mapped on read, not when it was stored")
    func cachedEntitiesAreMappedOnRead() async throws {
        let page = LocationsPageEntity(
            info: GraphQLPageInfo(count: 1, pages: 1, next: nil),
            results: [.make(name: "Earth", type: "  ", dimension: "unknown")]
        )
        let local = StubLocationsLocalDataSource(entries: [1: .fresh(page: page)])
        let repository = makeRepository(remote: StubLocationsRemoteDataSource(pages: [:]), local: local)

        let location = try #require(try await repository.fetchLocations(page: 1).locations.first)

        #expect(location.type == nil)
        #expect(location.dimension == "unknown")
    }

    // MARK: - Pagination

    @Test("nextPage is passed through from info.next")
    func nextPageIsPassedThrough() async throws {
        let remote = StubLocationsRemoteDataSource(pages: [
            1: .success(.make(names: ["Earth"], next: 2)),
            7: .success(.make(names: ["Bepis 9"], next: nil))
        ])
        let repository = makeRepository(remote: remote, local: StubLocationsLocalDataSource())

        #expect(try await repository.fetchLocations(page: 1).nextPage == 2)
        #expect(try await repository.fetchLocations(page: 7).nextPage == nil)
    }

    @Test("the requested page reaches the network")
    func theRequestedPageIsAskedFor() async throws {
        let remote = StubLocationsRemoteDataSource(pages: [
            1: .success(.make(names: ["Earth"], next: 2)),
            2: .success(.make(names: ["Abadango"], next: 3))
        ])
        let repository = makeRepository(remote: remote, local: StubLocationsLocalDataSource())

        _ = try await repository.fetchLocations(page: 1)
        _ = try await repository.fetchLocations(page: 2)

        #expect(await remote.requestedPages == [1, 2])
    }

    private func makeRepository(remote: StubLocationsRemoteDataSource,
                                local: StubLocationsLocalDataSource) -> LocationsRepository {
        LocationsRepository(remoteDataSource: remote,
                            localDataSource: local,
                            mapper: LocationEntityMapper())
    }
}

// MARK: - Test doubles

// MARK: - Fixtures

extension CacheEntry where Value == LocationsPageEntity {
    static func fresh(page: LocationsPageEntity) -> CacheEntry {
        CacheEntry(value: page, storedAt: .distantPast, expiresAt: .distantFuture, isExpired: false)
    }

    static func expired(page: LocationsPageEntity) -> CacheEntry {
        CacheEntry(value: page, storedAt: .distantPast, expiresAt: .distantPast, isExpired: true)
    }
}

extension LocationEntity {
    static func make(id: String? = "1",
                     name: String? = "Earth (C-137)",
                     type: String? = "Planet",
                     dimension: String? = "Dimension C-137",
                     residents: [LocationResidentEntity]? = [
                        .make(id: "1", name: "Rick Sanchez", image: URL(string: "https://example.com/1.jpeg")),
                        .make(id: "2", name: "Morty Smith", status: "Dead", image: URL(string: "https://example.com/2.jpeg"))
                     ]) -> LocationEntity {
        LocationEntity(id: id, name: name, type: type, dimension: dimension, residents: residents)
    }
}

extension LocationResidentEntity {
    static func make(id: String? = "1",
                     name: String? = "Rick Sanchez",
                     status: String? = "Alive",
                     species: String? = "Human",
                     image: URL? = URL(string: "https://example.com/1.jpeg")) -> LocationResidentEntity {
        LocationResidentEntity(id: id, name: name, status: status, species: species, image: image)
    }
}

extension GraphQLPageResponse where ResponseEntity == LocationEntity {
    static func make(names: [String], next: Int? = nil, pages: Int? = 1) -> LocationsPageEntity {
        LocationsPageEntity(
            info: GraphQLPageInfo(count: names.count, pages: pages, next: next),
            results: names.enumerated().map { index, name in
                LocationEntity.make(id: "\(index + 1)", name: name)
            }
        )
    }
}
