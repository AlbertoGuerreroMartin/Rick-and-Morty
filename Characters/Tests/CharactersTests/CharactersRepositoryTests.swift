//
//  CharactersRepositoryTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation
import Networking
import Storage
import Testing
@testable import Characters

/// The repository is where the cache policy lives, so these tests are the
/// policy: which of the two data sources answers, in each of the states the
/// pair can be in.
@Suite("CharactersRepository")
struct CharactersRepositoryTests {

    @Test("a fresh cache entry answers without touching the network")
    func freshCacheSkipsTheNetwork() async throws {
        let local = FakeCharactersLocalDataSource(entry: .fresh(page: .make(names: ["Rick Sanchez"])))
        let remote = FakeCharactersRemoteDataSource(result: .success(.make(names: ["From network"])))
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchCharacters(filter: .empty, page: 1)

        #expect(page.characters.map(\.name) == ["Rick Sanchez"])
        #expect(await remote.callCount == 0)
    }

    @Test("an expired entry is refreshed from the network and written back")
    func expiredCacheRefetchesAndStores() async throws {
        let local = FakeCharactersLocalDataSource(entry: .expired(page: .make(names: ["Yesterday"])))
        let remote = FakeCharactersRemoteDataSource(result: .success(.make(names: ["Rick Sanchez"])))
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchCharacters(filter: .empty, page: 1)

        #expect(page.characters.map(\.name) == ["Rick Sanchez"])
        #expect(await remote.callCount == 1)
        #expect(await local.storedPages.first?.results.first?.name == "Rick Sanchez")
    }

    @Test("a failed refresh falls back to the stale entry")
    func staleEntrySurvivesAFailedFetch() async throws {
        // This is the 429 case: the API throttles, and the user still gets the
        // list they were looking at yesterday instead of an error screen.
        let local = FakeCharactersLocalDataSource(entry: .expired(page: .make(names: ["Yesterday"])))
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()))
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchCharacters(filter: .empty, page: 1)

        #expect(page.characters.map(\.name) == ["Yesterday"])
    }

    @Test("with nothing cached, a failed fetch is an error")
    func noCacheAndFailedFetchThrows() async {
        let local = FakeCharactersLocalDataSource(entry: nil)
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()))
        let repository = makeRepository(remote: remote, local: local)

        await #expect(throws: TestError.self) {
            _ = try await repository.fetchCharacters(filter: .empty, page: 1)
        }
    }

    @Test("a cache read that throws is a miss, not a failure")
    func cacheReadFailureFallsThroughToTheNetwork() async throws {
        let local = FakeCharactersLocalDataSource(readError: TestError())
        let remote = FakeCharactersRemoteDataSource(result: .success(.make(names: ["Rick Sanchez"])))
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchCharacters(filter: .empty, page: 1)

        #expect(page.characters.map(\.name) == ["Rick Sanchez"])
        #expect(await remote.callCount == 1)
    }

    @Test("a cache write that throws still returns the fetched page")
    func cacheWriteFailureDoesNotFailTheFetch() async throws {
        let local = FakeCharactersLocalDataSource(entry: nil, writeError: TestError())
        let remote = FakeCharactersRemoteDataSource(result: .success(.make(names: ["Rick Sanchez"])))
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchCharacters(filter: .empty, page: 1)

        #expect(page.characters.map(\.name) == ["Rick Sanchez"])
    }

    @Test("cancellation is rethrown rather than answered from a stale entry")
    func cancellationIsRethrown() async {
        // Serving stale data here would hide the fact that the screen went away
        // and quietly defeat structured concurrency.
        let local = FakeCharactersLocalDataSource(entry: .expired(page: .make(names: ["Yesterday"])))
        let remote = FakeCharactersRemoteDataSource(result: .failure(CancellationError()))
        let repository = makeRepository(remote: remote, local: local)

        await #expect(throws: CancellationError.self) {
            _ = try await repository.fetchCharacters(filter: .empty, page: 1)
        }
    }

    @Test("nextPage comes straight off the page info")
    func nextPageIsCarriedThrough() async throws {
        let local = FakeCharactersLocalDataSource(entry: .fresh(page: .make(names: ["Rick"], next: 2)))
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()))
        let repository = makeRepository(remote: remote, local: local)

        #expect(try await repository.fetchCharacters(filter: .empty, page: 1).nextPage == 2)
    }

    @Test("one unmappable entity is skipped, not fatal to the page")
    func unmappableEntitiesAreSkipped() async throws {
        let broken = CharacterEntity(id: nil, name: nil, status: nil, species: nil,
                                     image: nil, origin: nil, location: nil)
        let page = CharactersPageEntity(
            info: GraphQLPageInfo(count: 2, pages: 1, next: nil),
            results: [broken, .make(name: "Rick Sanchez")]
        )
        let local = FakeCharactersLocalDataSource(entry: .fresh(page: page))
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()))
        let repository = makeRepository(remote: remote, local: local)

        #expect(try await repository.fetchCharacters(filter: .empty, page: 1).characters.map(\.name) == ["Rick Sanchez"])
    }

    @Test("purging the cache wipes the local data source")
    func purgeCacheWipesTheLocalDataSource() async throws {
        let local = FakeCharactersLocalDataSource()
        let repository = makeRepository(remote: FakeCharactersRemoteDataSource(result: .failure(TestError())),
                                        local: local)

        try await repository.purgeCache()

        #expect(await local.removeAllCallCount == 1)
    }

    @Test("a purge that fails on disk is reported, not swallowed")
    func purgeCacheRethrows() async {
        let local = FakeCharactersLocalDataSource(writeError: TestError())
        let repository = makeRepository(remote: FakeCharactersRemoteDataSource(result: .failure(TestError())),
                                        local: local)

        await #expect(throws: TestError.self) {
            try await repository.purgeCache()
        }
    }

    /// The filter has to reach the query, or every constraint the user sets is
    /// silently dropped and the list quietly lies about what it is showing.
    @Test("every filter field reaches the query")
    func filterFieldsReachTheQuery() async throws {
        let local = FakeCharactersLocalDataSource(entry: nil)
        let remote = FakeCharactersRemoteDataSource(result: .success(.make(names: ["Rick Sanchez"])))
        let repository = makeRepository(remote: remote, local: local)
        let filter = CharactersFilter(name: "Rick",
                                      status: .alive,
                                      species: "Human",
                                      type: "Parasite",
                                      gender: .female)

        _ = try await repository.fetchCharacters(filter: filter, page: 2)

        let query = try #require(await remote.lastQuery)
        #expect(query.page == 2)
        #expect(query.name == "Rick")
        #expect(query.status == .alive)
        #expect(query.species == "Human")
        #expect(query.type == "Parasite")
        #expect(query.gender == .female)
    }

    /// The identity of an *unfiltered* page must not change now that filters
    /// exist: the cache key is derived from the document and the encoded
    /// variables, and both drop `nil` optionals, so the pages already on disk
    /// stay addressable instead of ageing out on the first launch after this
    /// feature ships.
    @Test("an empty filter builds exactly the unfiltered query")
    func emptyFilterKeepsTheUnfilteredCacheIdentity() async throws {
        let local = FakeCharactersLocalDataSource(entry: nil)
        let remote = FakeCharactersRemoteDataSource(result: .success(.make(names: ["Rick Sanchez"])))
        let repository = makeRepository(remote: remote, local: local)

        _ = try await repository.fetchCharacters(filter: .empty, page: 1)

        let query = try #require(await remote.lastQuery)
        #expect(query.cacheIdentifier == CharactersQuery(page: 1).cacheIdentifier)
        #expect(query.name == nil)
        #expect(query.status == nil)
        #expect(query.species == nil)
        #expect(query.type == nil)
        #expect(query.gender == nil)
    }

    private func makeRepository(remote: FakeCharactersRemoteDataSource,
                                local: FakeCharactersLocalDataSource) -> CharactersRepository {
        CharactersRepository(remoteDataSource: remote,
                             localDataSource: local,
                             mapper: CharacterEntityMapper())
    }
}

// MARK: - Test doubles

struct TestError: Error, Equatable {}

actor FakeCharactersRemoteDataSource: CharactersRemoteDataSourceContract {
    private let result: Result<CharactersPageEntity, any Error>
    private(set) var callCount = 0
    /// The query as the repository built it. Recording it is the only way to
    /// check the filter mapping without reaching into the repository: the query
    /// is a private local, and the network is where it becomes observable.
    private(set) var lastQuery: CharactersQuery?

    init(result: Result<CharactersPageEntity, any Error>) {
        self.result = result
    }

    func fetchCharactersPage(_ query: CharactersQuery) async throws -> CharactersPageEntity {
        callCount += 1
        lastQuery = query
        return try result.get()
    }

    func fetchCharacterDetail(_ query: CharacterDetailQuery) async throws -> CharacterDetailEntity {
        throw TestError()
    }
}

actor FakeCharactersLocalDataSource: CharactersLocalDataSourceContract {
    private let entry: CacheEntry<CharactersPageEntity>?
    private let readError: (any Error)?
    private let writeError: (any Error)?
    private(set) var storedPages: [CharactersPageEntity] = []
    private(set) var removeAllCallCount = 0

    init(entry: CacheEntry<CharactersPageEntity>? = nil,
         readError: (any Error)? = nil,
         writeError: (any Error)? = nil) {
        self.entry = entry
        self.readError = readError
        self.writeError = writeError
    }

    func charactersPage(for query: CharactersQuery) async throws -> CacheEntry<CharactersPageEntity>? {
        if let readError { throw readError }
        return entry
    }

    func store(_ page: CharactersPageEntity, for query: CharactersQuery) async throws {
        if let writeError { throw writeError }
        storedPages.append(page)
    }

    func characterDetail(for query: CharacterDetailQuery) async throws -> CacheEntry<CharacterDetailEntity>? {
        if let readError { throw readError }
        return nil
    }

    func store(_ detail: CharacterDetailEntity, for query: CharacterDetailQuery) async throws {
        if let writeError { throw writeError }
    }

    func removeAll() async throws {
        if let writeError { throw writeError }
        removeAllCallCount += 1
    }
}

// MARK: - Fixtures

extension CacheEntry where Value == CharactersPageEntity {
    static func fresh(page: CharactersPageEntity) -> CacheEntry {
        CacheEntry(value: page, storedAt: .distantPast, expiresAt: .distantFuture, isExpired: false)
    }

    static func expired(page: CharactersPageEntity) -> CacheEntry {
        CacheEntry(value: page, storedAt: .distantPast, expiresAt: .distantPast, isExpired: true)
    }
}

extension CharacterEntity {
    static func make(name: String) -> CharacterEntity {
        CharacterEntity(id: name,
                        name: name,
                        status: "Alive",
                        species: "Human",
                        image: URL(string: "https://example.com/\(name).jpeg"),
                        origin: nil,
                        location: CharacterLocationEntity(name: "Earth", dimension: nil))
    }
}

extension GraphQLPageResponse where ResponseEntity == CharacterEntity {
    static func make(names: [String], next: Int? = nil) -> CharactersPageEntity {
        CharactersPageEntity(
            info: GraphQLPageInfo(count: names.count, pages: 1, next: next),
            results: names.map(CharacterEntity.make(name:))
        )
    }
}
