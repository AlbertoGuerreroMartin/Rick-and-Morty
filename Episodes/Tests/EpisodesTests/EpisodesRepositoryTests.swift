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

    private func makeRepository(remote: FakeEpisodesRemoteDataSource,
                                local: FakeEpisodesLocalDataSource,
                                links: FakeHBOMaxLinksRemoteDataSource = FakeHBOMaxLinksRemoteDataSource()) -> EpisodesRepository {
        EpisodesRepository(remoteDataSource: remote,
                           hboMaxLinksRemoteDataSource: links,
                           localDataSource: local,
                           mapper: EpisodeEntityMapper(),
                           linksMapper: HBOMaxLinksMapper())
    }
}

@Suite("EpisodesRepository HBO Max links")
struct EpisodesRepositoryHBOMaxLinksTests {

    @Test("a fresh cache entry answers without touching JustWatch")
    func freshCacheSkipsTheNetwork() async throws {
        let hboLinkA = "https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444"
        let hboLinkB = "https://play.hbomax.com/video/watch/bbbbbbbb-1111-2222-3333-444444444444"
        let local = FakeEpisodesLocalDataSource(offers: .fresh(offers: .oneEpisode(link: hboLinkA)))
        let links = FakeHBOMaxLinksRemoteDataSource(result: .success(.oneEpisode(link: hboLinkB)))
        let repository = makeRepository(local: local, links: links)

        let fetched = try await repository.fetchHBOMaxLinks()

        #expect(fetched.url(season: 1, number: 1)?.absoluteString.contains("aaaaaaaa") == true)
        #expect(await links.callCount == 0)
    }

    @Test("an expired entry is refreshed from JustWatch and written back")
    func expiredCacheRefetchesAndStores() async throws {
        let hboLinkA = "https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444"
        let hboLinkB = "https://play.hbomax.com/video/watch/bbbbbbbb-1111-2222-3333-444444444444"
        let local = FakeEpisodesLocalDataSource(offers: .expired(offers: .oneEpisode(link: hboLinkA)))
        let links = FakeHBOMaxLinksRemoteDataSource(result: .success(.oneEpisode(link: hboLinkB)))
        let repository = makeRepository(local: local, links: links)

        let fetched = try await repository.fetchHBOMaxLinks()

        #expect(fetched.url(season: 1, number: 1)?.absoluteString.contains("bbbbbbbb") == true)
        #expect(await links.callCount == 1)
        #expect(await local.storedOffers.count == 1)
    }

    @Test("a failed refresh falls back to the stale entry")
    func staleEntrySurvivesAFailedFetch() async throws {
        let hboLink = "https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444"
        let local = FakeEpisodesLocalDataSource(offers: .expired(offers: .oneEpisode(link: hboLink)))
        let repository = makeRepository(local: local,
                                        links: FakeHBOMaxLinksRemoteDataSource(result: .failure(TestError())))

        #expect(try await repository.fetchHBOMaxLinks().url(season: 1, number: 1) != nil)
    }

    @Test("with nothing cached, a failed fetch is an error")
    func noCacheAndFailedFetchThrows() async {
        let repository = makeRepository(local: FakeEpisodesLocalDataSource(),
                                        links: FakeHBOMaxLinksRemoteDataSource(result: .failure(TestError())))

        await #expect(throws: TestError.self) {
            _ = try await repository.fetchHBOMaxLinks()
        }
    }

    @Test("a cache read that throws is a miss, not a failure")
    func cacheReadFailureFallsThroughToTheNetwork() async throws {
        let hboLink = "https://play.hbomax.com/video/watch/bbbbbbbb-1111-2222-3333-444444444444"
        let local = FakeEpisodesLocalDataSource(readError: TestError())
        let links = FakeHBOMaxLinksRemoteDataSource(result: .success(.oneEpisode(link: hboLink)))
        let repository = makeRepository(local: local, links: links)

        #expect(try await repository.fetchHBOMaxLinks().url(season: 1, number: 1) != nil)
        #expect(await links.callCount == 1)
    }

    @Test("a cache write that throws still returns the links")
    func cacheWriteFailureDoesNotFailTheFetch() async throws {
        let hboLink = "https://play.hbomax.com/video/watch/bbbbbbbb-1111-2222-3333-444444444444"
        let local = FakeEpisodesLocalDataSource(writeError: TestError())
        let links = FakeHBOMaxLinksRemoteDataSource(result: .success(.oneEpisode(link: hboLink)))
        let repository = makeRepository(local: local, links: links)

        #expect(try await repository.fetchHBOMaxLinks().url(season: 1, number: 1) != nil)
    }

    @Test("cancellation is rethrown rather than answered from a stale entry")
    func cancellationIsRethrown() async {
        let hboLink = "https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444"
        let local = FakeEpisodesLocalDataSource(offers: .expired(offers: .oneEpisode(link: hboLink)))
        let repository = makeRepository(local: local,
                                        links: FakeHBOMaxLinksRemoteDataSource(result: .failure(CancellationError())))

        await #expect(throws: CancellationError.self) {
            _ = try await repository.fetchHBOMaxLinks()
        }
    }

    @Test("a cached entity is mapped on read, not when it was stored")
    func cachedOffersAreMappedOnRead() async throws {
        let hboLink = "https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444?utm_source=universal_search"
        let local = FakeEpisodesLocalDataSource(offers: .fresh(offers: .oneEpisode(
            link: hboLink
        )))

        let fetched = try await makeRepository(local: local).fetchHBOMaxLinks()

        #expect(fetched.url(season: 1, number: 1)?.absoluteString
                == "https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444")
    }

    private func makeRepository(local: FakeEpisodesLocalDataSource,
                                links: FakeHBOMaxLinksRemoteDataSource = FakeHBOMaxLinksRemoteDataSource()) -> EpisodesRepository {
        EpisodesRepository(remoteDataSource: FakeEpisodesRemoteDataSource(pages: [:]),
                           hboMaxLinksRemoteDataSource: links,
                           localDataSource: local,
                           mapper: EpisodeEntityMapper(),
                           linksMapper: HBOMaxLinksMapper())
    }
}

// MARK: - Test doubles

struct TestError: Error, Equatable {}

/// Keyed on the page number, the only handle a test has since the repository builds the query.
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
    /// Only ever one offers entry: the lookup is one request for the whole show.
    private let offers: CacheEntry<JustWatchShowEntity>?
    private let readError: (any Error)?
    private let writeError: (any Error)?
    private(set) var storedPages: [EpisodesPageEntity] = []
    private(set) var storedOffers: [JustWatchShowEntity] = []
    private(set) var removeAllCallCount = 0

    init(entries: [Int: CacheEntry<EpisodesPageEntity>] = [:],
         offers: CacheEntry<JustWatchShowEntity>? = nil,
         readError: (any Error)? = nil,
         writeError: (any Error)? = nil) {
        self.entries = entries
        self.offers = offers
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

    func showOffers(for query: JustWatchShowOffersQuery) async throws -> CacheEntry<JustWatchShowEntity>? {
        if let readError { throw readError }
        return offers
    }

    func store(_ offers: JustWatchShowEntity, for query: JustWatchShowOffersQuery) async throws {
        if let writeError { throw writeError }
        storedOffers.append(offers)
    }

    func removeAll() async throws {
        if let writeError { throw writeError }
        removeAllCallCount += 1
    }
}

actor FakeHBOMaxLinksRemoteDataSource: HBOMaxLinksRemoteDataSourceContract {
    private let result: Result<JustWatchShowEntity, any Error>
    private(set) var callCount = 0

    init(result: Result<JustWatchShowEntity, any Error> = .success(JustWatchShowEntity(seasons: nil))) {
        self.result = result
    }

    func fetchShowOffers(_ query: JustWatchShowOffersQuery) async throws -> JustWatchShowEntity {
        callCount += 1
        return try result.get()
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

extension CacheEntry where Value == JustWatchShowEntity {
    static func fresh(offers: JustWatchShowEntity) -> CacheEntry {
        CacheEntry(value: offers, storedAt: .distantPast, expiresAt: .distantFuture, isExpired: false)
    }

    static func expired(offers: JustWatchShowEntity) -> CacheEntry {
        CacheEntry(value: offers, storedAt: .distantPast, expiresAt: .distantPast, isExpired: true)
    }
}

extension JustWatchShowEntity {
    /// Season 1, episode 1, on HBO Max at `link`.
    static func oneEpisode(link: String) -> JustWatchShowEntity {
        .make(episodes: [.make(season: 1, number: 1, offers: [.max(link)])])
    }
}

extension EpisodeEntity {
    static func make(id: String? = "1",
                     name: String? = "Pilot",
                     airDate: String? = "December 2, 2013",
                     code: String? = "S01E01",
                     created: String? = "2021-10-15T17:00:24.105Z",
                     characters: [EpisodeCharacterEntity]? = [
                        EpisodeCharacterEntity(id: "1", name: "Rick Sanchez",
                                               image: URL(string: "https://example.com/1.jpeg")),
                        EpisodeCharacterEntity(id: "2", name: "Morty Smith",
                                               image: URL(string: "https://example.com/2.jpeg"))
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
