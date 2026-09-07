//
//  EpisodesRepositoryTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Storage
import Testing
@testable import Episodes

/// The repository is where the cache policy and the catalogue walk live, so
/// these tests are both: which of the two data sources answers in each state the
/// pair can be in, and what the walk does with the pages it collects.
@Suite("EpisodesRepository")
struct EpisodesRepositoryTests {

    // MARK: - Cache policy, per page

    @Test("a fresh cache entry answers without touching the network")
    func freshCacheSkipsTheNetwork() async throws {
        let local = FakeEpisodesLocalDataSource(entries: [1: .fresh(page: .make(codes: ["S01E01"]))])
        let remote = FakeEpisodesRemoteDataSource(pages: [1: .success(.make(codes: ["S09E09"]))])
        let repository = makeRepository(remote: remote, local: local)

        let episodes = try await repository.fetchEpisodes()

        #expect(episodes.map(\.code) == ["S01E01"])
        #expect(await remote.callCount == 0)
    }

    @Test("an expired entry is refreshed from the network and written back")
    func expiredCacheRefetchesAndStores() async throws {
        let local = FakeEpisodesLocalDataSource(entries: [1: .expired(page: .make(codes: ["S01E01"]))])
        let remote = FakeEpisodesRemoteDataSource(pages: [1: .success(.make(codes: ["S02E02"]))])
        let repository = makeRepository(remote: remote, local: local)

        let episodes = try await repository.fetchEpisodes()

        #expect(episodes.map(\.code) == ["S02E02"])
        #expect(await remote.callCount == 1)
        #expect(await local.storedPages.first?.results.first?.episode == "S02E02")
    }

    @Test("a failed refresh falls back to the stale entry")
    func staleEntrySurvivesAFailedFetch() async throws {
        // This is the 429 case: the API throttles, and the user still gets the
        // catalogue they were looking at last week instead of an error screen.
        let local = FakeEpisodesLocalDataSource(entries: [1: .expired(page: .make(codes: ["S01E01"]))])
        let remote = FakeEpisodesRemoteDataSource(pages: [1: .failure(TestError())])
        let repository = makeRepository(remote: remote, local: local)

        #expect(try await repository.fetchEpisodes().map(\.code) == ["S01E01"])
    }

    @Test("with nothing cached, a failed fetch is an error")
    func noCacheAndFailedFetchThrows() async {
        let local = FakeEpisodesLocalDataSource()
        let remote = FakeEpisodesRemoteDataSource(pages: [1: .failure(TestError())])
        let repository = makeRepository(remote: remote, local: local)

        await #expect(throws: TestError.self) {
            _ = try await repository.fetchEpisodes()
        }
    }

    @Test("a cache read that throws is a miss, not a failure")
    func cacheReadFailureFallsThroughToTheNetwork() async throws {
        let local = FakeEpisodesLocalDataSource(readError: TestError())
        let remote = FakeEpisodesRemoteDataSource(pages: [1: .success(.make(codes: ["S01E01"]))])
        let repository = makeRepository(remote: remote, local: local)

        #expect(try await repository.fetchEpisodes().map(\.code) == ["S01E01"])
        #expect(await remote.callCount == 1)
    }

    @Test("a cache write that throws still returns the fetched page")
    func cacheWriteFailureDoesNotFailTheFetch() async throws {
        let local = FakeEpisodesLocalDataSource(writeError: TestError())
        let remote = FakeEpisodesRemoteDataSource(pages: [1: .success(.make(codes: ["S01E01"]))])
        let repository = makeRepository(remote: remote, local: local)

        #expect(try await repository.fetchEpisodes().map(\.code) == ["S01E01"])
    }

    @Test("cancellation is rethrown rather than answered from a stale entry")
    func cancellationIsRethrown() async {
        // Serving stale data here would hide the fact that the screen went away
        // and quietly defeat structured concurrency.
        let local = FakeEpisodesLocalDataSource(entries: [1: .expired(page: .make(codes: ["S01E01"]))])
        let remote = FakeEpisodesRemoteDataSource(pages: [1: .failure(CancellationError())])
        let repository = makeRepository(remote: remote, local: local)

        await #expect(throws: CancellationError.self) {
            _ = try await repository.fetchEpisodes()
        }
    }

    // MARK: - The catalogue walk

    @Test("the walk follows info.next and concatenates the pages in order")
    func multiPageWalkConcatenatesInOrder() async throws {
        let remote = FakeEpisodesRemoteDataSource(pages: [
            1: .success(.make(codes: ["S01E01", "S01E02"], next: 2, pages: 3)),
            2: .success(.make(codes: ["S02E01"], next: 3, pages: 3)),
            3: .success(.make(codes: ["S03E01"], next: nil, pages: 3))
        ])
        let repository = makeRepository(remote: remote, local: FakeEpisodesLocalDataSource())

        let episodes = try await repository.fetchEpisodes()

        #expect(episodes.map(\.code) == ["S01E01", "S01E02", "S02E01", "S03E01"])
        #expect(await remote.requestedPages == [1, 2, 3])
    }

    /// Each page is asked for exactly once. A walk that re-requested a page
    /// would triple the cost of the one thing this screen does on load.
    @Test("each page is requested once")
    func eachPageIsRequestedOnce() async throws {
        let remote = FakeEpisodesRemoteDataSource(pages: [
            1: .success(.make(codes: ["S01E01"], next: 2, pages: 2)),
            2: .success(.make(codes: ["S02E01"], next: nil, pages: 2))
        ])
        let repository = makeRepository(remote: remote, local: FakeEpisodesLocalDataSource())

        _ = try await repository.fetchEpisodes()

        #expect(await remote.requestedPages == [1, 2])
    }

    /// Half a catalogue would silently break the local search — the whole reason
    /// the walk exists — so a page that cannot be answered fails the load rather
    /// than returning what it managed to collect.
    @Test("a later page failing with nothing cached fails the whole load")
    func aFailedLaterPageFailsTheLoad() async {
        let remote = FakeEpisodesRemoteDataSource(pages: [
            1: .success(.make(codes: ["S01E01"], next: 2, pages: 2)),
            2: .failure(TestError())
        ])
        let repository = makeRepository(remote: remote, local: FakeEpisodesLocalDataSource())

        await #expect(throws: TestError.self) {
            _ = try await repository.fetchEpisodes()
        }
    }

    /// A half-cached catalogue costs only the missing requests, because the
    /// policy is applied per page rather than to the walk as a whole.
    @Test("a cached page in the middle of the walk is not refetched")
    func cachedPagesInTheWalkSkipTheNetwork() async throws {
        let local = FakeEpisodesLocalDataSource(entries: [
            2: .fresh(page: .make(codes: ["S02E01"], next: 3, pages: 3))
        ])
        let remote = FakeEpisodesRemoteDataSource(pages: [
            1: .success(.make(codes: ["S01E01"], next: 2, pages: 3)),
            3: .success(.make(codes: ["S03E01"], next: nil, pages: 3))
        ])
        let repository = makeRepository(remote: remote, local: local)

        let episodes = try await repository.fetchEpisodes()

        #expect(episodes.map(\.code) == ["S01E01", "S02E01", "S03E01"])
        #expect(await remote.requestedPages == [1, 3])
    }

    /// `info.next` is the server's word. A malformed answer pointing back at a
    /// page already walked must stop the walk, not loop forever.
    @Test("a next pointer that repeats a page stops the walk")
    func aRepeatedNextPointerStopsTheWalk() async throws {
        let remote = FakeEpisodesRemoteDataSource(pages: [
            1: .success(.make(codes: ["S01E01"], next: 2, pages: nil)),
            2: .success(.make(codes: ["S02E01"], next: 1, pages: nil))
        ])
        let repository = makeRepository(remote: remote, local: FakeEpisodesLocalDataSource())

        let episodes = try await repository.fetchEpisodes()

        #expect(episodes.map(\.code) == ["S01E01", "S02E01"])
        #expect(await remote.requestedPages == [1, 2])
    }

    /// The other guard: `info.pages` bounds the walk even when `next` keeps
    /// pointing at pages that have not been seen yet.
    @Test("the walk never runs longer than info.pages says it should")
    func thePageCountBoundsTheWalk() async throws {
        let remote = FakeEpisodesRemoteDataSource(pages: [
            1: .success(.make(codes: ["S01E01"], next: 2, pages: 2)),
            2: .success(.make(codes: ["S02E01"], next: 3, pages: 2)),
            3: .success(.make(codes: ["S03E01"], next: 4, pages: 2))
        ])
        let repository = makeRepository(remote: remote, local: FakeEpisodesLocalDataSource())

        let episodes = try await repository.fetchEpisodes()

        #expect(episodes.map(\.code) == ["S01E01", "S02E01"])
        #expect(await remote.requestedPages == [1, 2])
    }

    @Test("one unmappable entity is skipped, not fatal to the page")
    func unmappableEntitiesAreSkipped() async throws {
        let broken = EpisodeEntity(id: nil, name: nil, air_date: nil,
                                   episode: nil, created: nil, characters: nil)
        let page = EpisodesPageEntity(
            info: GraphQLPageInfo(count: 2, pages: 1, next: nil),
            results: [broken, .make(code: "S01E01")]
        )
        let local = FakeEpisodesLocalDataSource(entries: [1: .fresh(page: page)])
        let repository = makeRepository(remote: FakeEpisodesRemoteDataSource(pages: [:]), local: local)

        #expect(try await repository.fetchEpisodes().map(\.code) == ["S01E01"])
    }

    // MARK: - Purge

    @Test("purging the cache wipes the local data source")
    func purgeCacheWipesTheLocalDataSource() async throws {
        let local = FakeEpisodesLocalDataSource()
        let repository = makeRepository(remote: FakeEpisodesRemoteDataSource(pages: [:]), local: local)

        try await repository.purgeCache()

        #expect(await local.removeAllCallCount == 1)
    }

    @Test("a purge that fails on disk is reported, not swallowed")
    func purgeCacheRethrows() async {
        let local = FakeEpisodesLocalDataSource(writeError: TestError())
        let repository = makeRepository(remote: FakeEpisodesRemoteDataSource(pages: [:]), local: local)

        await #expect(throws: TestError.self) {
            try await repository.purgeCache()
        }
    }

    private func makeRepository(remote: FakeEpisodesRemoteDataSource,
                                local: FakeEpisodesLocalDataSource) -> EpisodesRepository {
        EpisodesRepository(remoteDataSource: remote,
                           localDataSource: local,
                           mapper: EpisodeEntityMapper())
    }
}

// MARK: - Test doubles

struct TestError: Error, Equatable {}

/// Keyed on the page number rather than on the query: the repository builds the
/// query privately, so the page is the only handle a test has on "which request
/// is this" — and it is exactly the axis the walk is about.
actor FakeEpisodesRemoteDataSource: EpisodesRemoteDataSourceContract {
    private let pages: [Int: Result<EpisodesPageEntity, any Error>]
    private(set) var requestedPages: [Int] = []

    var callCount: Int { requestedPages.count }

    init(pages: [Int: Result<EpisodesPageEntity, any Error>]) {
        self.pages = pages
    }

    func fetchEpisodesPage(_ query: EpisodesQuery) async throws -> EpisodesPageEntity {
        let page = query.page ?? 1
        requestedPages.append(page)
        guard let result = pages[page] else { throw TestError() }
        return try result.get()
    }
}

actor FakeEpisodesLocalDataSource: EpisodesLocalDataSourceContract {
    private let entries: [Int: CacheEntry<EpisodesPageEntity>]
    private let readError: (any Error)?
    private let writeError: (any Error)?
    private(set) var storedPages: [EpisodesPageEntity] = []
    private(set) var removeAllCallCount = 0

    init(entries: [Int: CacheEntry<EpisodesPageEntity>] = [:],
         readError: (any Error)? = nil,
         writeError: (any Error)? = nil) {
        self.entries = entries
        self.readError = readError
        self.writeError = writeError
    }

    func episodesPage(for query: EpisodesQuery) async throws -> CacheEntry<EpisodesPageEntity>? {
        if let readError { throw readError }
        return entries[query.page ?? 1]
    }

    func store(_ page: EpisodesPageEntity, for query: EpisodesQuery) async throws {
        if let writeError { throw writeError }
        storedPages.append(page)
    }

    func removeAll() async throws {
        if let writeError { throw writeError }
        removeAllCallCount += 1
    }
}

// MARK: - Fixtures

extension CacheEntry where Value == EpisodesPageEntity {
    static func fresh(page: EpisodesPageEntity) -> CacheEntry {
        CacheEntry(value: page, storedAt: .distantPast, expiresAt: .distantFuture, isExpired: false)
    }

    static func expired(page: EpisodesPageEntity) -> CacheEntry {
        CacheEntry(value: page, storedAt: .distantPast, expiresAt: .distantPast, isExpired: true)
    }
}

extension EpisodeEntity {
    /// Every property defaults to something valid, so a test that is about one
    /// missing field says only that.
    static func make(id: String? = "1",
                     name: String? = "Pilot",
                     airDate: String? = "December 2, 2013",
                     code: String? = "S01E01",
                     created: String? = "2021-10-15T17:00:24.105Z",
                     characters: [EpisodeCharacterEntity]? = [
                        EpisodeCharacterEntity(id: "1", image: URL(string: "https://example.com/1.jpeg")),
                        EpisodeCharacterEntity(id: "2", image: URL(string: "https://example.com/2.jpeg"))
                     ]) -> EpisodeEntity {
        EpisodeEntity(id: id,
                      name: name,
                      air_date: airDate,
                      episode: code,
                      created: created,
                      characters: characters)
    }
}

extension GraphQLPageResponse where ResponseEntity == EpisodeEntity {
    static func make(codes: [String], next: Int? = nil, pages: Int? = 1) -> EpisodesPageEntity {
        EpisodesPageEntity(
            info: GraphQLPageInfo(count: codes.count, pages: pages, next: next),
            results: codes.map { EpisodeEntity.make(id: $0, name: "Episode \($0)", code: $0) }
        )
    }
}
