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

/// The repository is where the cache policy lives, so these tests are every
/// state the two data sources can be in between them — which of the pair answers,
/// and what the caller gets when one of them fails.
@Suite("LocationsRepository")
struct LocationsRepositoryTests {

    @Test("a fresh cache entry answers without touching the network")
    func freshCacheSkipsTheNetwork() async throws {
        let local = FakeLocationsLocalDataSource(entries: [1: .fresh(page: .make(names: ["Earth"]))])
        let remote = FakeLocationsRemoteDataSource(pages: [1: .success(.make(names: ["Abadango"]))])
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchLocations(page: 1)

        #expect(page.locations.map(\.name) == ["Earth"])
        #expect(await remote.callCount == 0)
    }

    @Test("an expired entry is refreshed from the network and written back")
    func expiredCacheRefetchesAndStores() async throws {
        let local = FakeLocationsLocalDataSource(entries: [1: .expired(page: .make(names: ["Earth"]))])
        let remote = FakeLocationsRemoteDataSource(pages: [1: .success(.make(names: ["Abadango"]))])
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchLocations(page: 1)

        #expect(page.locations.map(\.name) == ["Abadango"])
        #expect(await remote.callCount == 1)
        #expect(await local.storedPages.first?.results.first?.name == "Abadango")
    }

    /// This is the 429 case: the API throttles, and the user still gets the
    /// carousel they were looking at last week instead of an error screen.
    @Test("a failed refresh falls back to the stale entry")
    func staleEntrySurvivesAFailedFetch() async throws {
        let local = FakeLocationsLocalDataSource(entries: [1: .expired(page: .make(names: ["Earth"]))])
        let remote = FakeLocationsRemoteDataSource(pages: [1: .failure(TestError())])
        let repository = makeRepository(remote: remote, local: local)

        #expect(try await repository.fetchLocations(page: 1).locations.map(\.name) == ["Earth"])
    }

    @Test("with nothing cached, a failed fetch is an error")
    func noCacheAndFailedFetchThrows() async {
        let repository = makeRepository(remote: FakeLocationsRemoteDataSource(pages: [1: .failure(TestError())]),
                                        local: FakeLocationsLocalDataSource())

        await #expect(throws: TestError.self) {
            _ = try await repository.fetchLocations(page: 1)
        }
    }

    @Test("a cache read that throws is a miss, not a failure")
    func cacheReadFailureFallsThroughToTheNetwork() async throws {
        let local = FakeLocationsLocalDataSource(readError: TestError())
        let remote = FakeLocationsRemoteDataSource(pages: [1: .success(.make(names: ["Earth"]))])
        let repository = makeRepository(remote: remote, local: local)

        #expect(try await repository.fetchLocations(page: 1).locations.map(\.name) == ["Earth"])
        #expect(await remote.callCount == 1)
    }

    @Test("a cache write that throws still returns the fetched page")
    func cacheWriteFailureDoesNotFailTheFetch() async throws {
        let local = FakeLocationsLocalDataSource(writeError: TestError())
        let remote = FakeLocationsRemoteDataSource(pages: [1: .success(.make(names: ["Earth"]))])
        let repository = makeRepository(remote: remote, local: local)

        #expect(try await repository.fetchLocations(page: 1).locations.map(\.name) == ["Earth"])
    }

    /// Serving stale data here would hide the fact that the screen went away and
    /// quietly defeat structured concurrency.
    @Test("cancellation is rethrown rather than answered from a stale entry")
    func cancellationIsRethrown() async {
        let local = FakeLocationsLocalDataSource(entries: [1: .expired(page: .make(names: ["Earth"]))])
        let remote = FakeLocationsRemoteDataSource(pages: [1: .failure(CancellationError())])
        let repository = makeRepository(remote: remote, local: local)

        await #expect(throws: CancellationError.self) {
            _ = try await repository.fetchLocations(page: 1)
        }
    }

    // MARK: - Mapping

    /// One nameless location should not blank twenty circles.
    @Test("one unmappable entity is skipped, not fatal to the page")
    func unmappableEntitiesAreSkipped() async throws {
        let broken = LocationEntity(id: nil, name: nil, type: nil, dimension: nil, residents: nil)
        let page = LocationsPageEntity(info: GraphQLPageInfo(count: 2, pages: 1, next: nil),
                                       results: [broken, .make(name: "Earth")])
        let local = FakeLocationsLocalDataSource(entries: [1: .fresh(page: page)])
        let repository = makeRepository(remote: FakeLocationsRemoteDataSource(pages: [:]), local: local)

        #expect(try await repository.fetchLocations(page: 1).locations.map(\.name) == ["Earth"])
    }

    /// The cache stores entities, so the normalisation rules run on every read —
    /// a week-old entry is mapped by today's mapper rather than by whatever the
    /// rules were when it was written.
    @Test("a cached entity is mapped on read, not when it was stored")
    func cachedEntitiesAreMappedOnRead() async throws {
        let page = LocationsPageEntity(
            info: GraphQLPageInfo(count: 1, pages: 1, next: nil),
            results: [.make(name: "Earth", type: "  ", dimension: "unknown")]
        )
        let local = FakeLocationsLocalDataSource(entries: [1: .fresh(page: page)])
        let repository = makeRepository(remote: FakeLocationsRemoteDataSource(pages: [:]), local: local)

        let location = try #require(try await repository.fetchLocations(page: 1).locations.first)

        #expect(location.type == nil)
        #expect(location.dimension == "unknown")
    }

    // MARK: - Pagination

    /// `info.next` is the only thing that says whether there is more, and the
    /// page number is the whole request — so both have to survive the trip
    /// through the repository untouched.
    @Test("nextPage is passed through from info.next")
    func nextPageIsPassedThrough() async throws {
        let remote = FakeLocationsRemoteDataSource(pages: [
            1: .success(.make(names: ["Earth"], next: 2)),
            7: .success(.make(names: ["Bepis 9"], next: nil))
        ])
        let repository = makeRepository(remote: remote, local: FakeLocationsLocalDataSource())

        #expect(try await repository.fetchLocations(page: 1).nextPage == 2)
        #expect(try await repository.fetchLocations(page: 7).nextPage == nil)
    }

    /// Each page addresses its own cache entry and its own request, which is
    /// what the query built inside `fetchLocations` is for.
    @Test("the requested page reaches the network")
    func theRequestedPageIsAskedFor() async throws {
        let remote = FakeLocationsRemoteDataSource(pages: [
            1: .success(.make(names: ["Earth"], next: 2)),
            2: .success(.make(names: ["Abadango"], next: 3))
        ])
        let repository = makeRepository(remote: remote, local: FakeLocationsLocalDataSource())

        _ = try await repository.fetchLocations(page: 1)
        _ = try await repository.fetchLocations(page: 2)

        #expect(await remote.requestedPages == [1, 2])
    }

    private func makeRepository(remote: FakeLocationsRemoteDataSource,
                                local: FakeLocationsLocalDataSource) -> LocationsRepository {
        LocationsRepository(remoteDataSource: remote,
                            localDataSource: local,
                            mapper: LocationEntityMapper())
    }
}

// MARK: - Test doubles

struct TestError: Error, Equatable {}

/// Keyed on the page number rather than on the query: the repository builds the
/// query privately, so the page is the only handle a test has on "which request
/// is this" — and it is exactly the axis pagination is about.
actor FakeLocationsRemoteDataSource: LocationsRemoteDataSourceContract {
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

actor FakeLocationsLocalDataSource: LocationsLocalDataSourceContract {
    private let entries: [Int: CacheEntry<LocationsPageEntity>]
    private let readError: (any Error)?
    private let writeError: (any Error)?
    private(set) var storedPages: [LocationsPageEntity] = []
    private(set) var removeAllCallCount = 0

    init(entries: [Int: CacheEntry<LocationsPageEntity>] = [:],
         readError: (any Error)? = nil,
         writeError: (any Error)? = nil) {
        self.entries = entries
        self.readError = readError
        self.writeError = writeError
    }

    func locationsPage(for query: LocationsQuery) async throws -> CacheEntry<LocationsPageEntity>? {
        if let readError { throw readError }
        return entries[query.page ?? 1]
    }

    func store(_ page: LocationsPageEntity, for query: LocationsQuery) async throws {
        if let writeError { throw writeError }
        storedPages.append(page)
    }

    func removeAll() async throws {
        if let writeError { throw writeError }
        removeAllCallCount += 1
    }
}

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
    /// Every property defaults to something valid, so a test that is about one
    /// missing field says only that.
    static func make(id: String? = "1",
                     name: String? = "Earth (C-137)",
                     type: String? = "Planet",
                     dimension: String? = "Dimension C-137",
                     residents: [LocationResidentEntity]? = [
                        LocationResidentEntity(id: "1", name: "Rick Sanchez", image: URL(string: "https://example.com/1.jpeg")),
                        LocationResidentEntity(id: "2", name: "Morty Smith", image: URL(string: "https://example.com/2.jpeg"))
                     ]) -> LocationEntity {
        LocationEntity(id: id, name: name, type: type, dimension: dimension, residents: residents)
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
