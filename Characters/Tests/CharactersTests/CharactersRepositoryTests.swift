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

        let page = try await repository.fetchCharacters(page: 1)

        #expect(page.characters.map(\.name) == ["Rick Sanchez"])
        #expect(await remote.callCount == 0)
    }

    @Test("an expired entry is refreshed from the network and written back")
    func expiredCacheRefetchesAndStores() async throws {
        let local = FakeCharactersLocalDataSource(entry: .expired(page: .make(names: ["Yesterday"])))
        let remote = FakeCharactersRemoteDataSource(result: .success(.make(names: ["Rick Sanchez"])))
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchCharacters(page: 1)

        #expect(page.characters.map(\.name) == ["Rick Sanchez"])
        #expect(await remote.callCount == 1)
        #expect(await local.storedPages.first?.results.first?.name == "Rick Sanchez")
    }

    @Test("a failed refresh falls back to the stale entry")
    func staleEntrySurvivesAFailedFetch() async throws {
        // This is the 419 case: the API throttles, and the user still gets the
        // list they were looking at yesterday instead of an error screen.
        let local = FakeCharactersLocalDataSource(entry: .expired(page: .make(names: ["Yesterday"])))
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()))
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchCharacters(page: 1)

        #expect(page.characters.map(\.name) == ["Yesterday"])
    }

    @Test("with nothing cached, a failed fetch is an error")
    func noCacheAndFailedFetchThrows() async {
        let local = FakeCharactersLocalDataSource(entry: nil)
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()))
        let repository = makeRepository(remote: remote, local: local)

        await #expect(throws: TestError.self) {
            _ = try await repository.fetchCharacters(page: 1)
        }
    }

    @Test("a cache read that throws is a miss, not a failure")
    func cacheReadFailureFallsThroughToTheNetwork() async throws {
        let local = FakeCharactersLocalDataSource(readError: TestError())
        let remote = FakeCharactersRemoteDataSource(result: .success(.make(names: ["Rick Sanchez"])))
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchCharacters(page: 1)

        #expect(page.characters.map(\.name) == ["Rick Sanchez"])
        #expect(await remote.callCount == 1)
    }

    @Test("a cache write that throws still returns the fetched page")
    func cacheWriteFailureDoesNotFailTheFetch() async throws {
        let local = FakeCharactersLocalDataSource(entry: nil, writeError: TestError())
        let remote = FakeCharactersRemoteDataSource(result: .success(.make(names: ["Rick Sanchez"])))
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchCharacters(page: 1)

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
            _ = try await repository.fetchCharacters(page: 1)
        }
    }

    @Test("nextPage comes straight off the page info")
    func nextPageIsCarriedThrough() async throws {
        let local = FakeCharactersLocalDataSource(entry: .fresh(page: .make(names: ["Rick"], next: 2)))
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()))
        let repository = makeRepository(remote: remote, local: local)

        #expect(try await repository.fetchCharacters(page: 1).nextPage == 2)
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

        #expect(try await repository.fetchCharacters(page: 1).characters.map(\.name) == ["Rick Sanchez"])
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

    init(result: Result<CharactersPageEntity, any Error>) {
        self.result = result
    }

    func fetchCharactersPage(_ query: CharactersQuery) async throws -> CharactersPageEntity {
        callCount += 1
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
