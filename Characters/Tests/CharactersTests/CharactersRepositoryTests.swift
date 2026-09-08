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
        makeCharactersRepository(remote: remote, local: local)
    }
}

// MARK: - The character detail

/// The detail runs on the very same four steps as a page — the policy is
/// extracted, not copied — so these walk the same branches once more against the
/// one request that has no fallback: a detail that does not arrive is the whole
/// screen, not one row of it.
@Suite("CharactersRepository: the character detail")
struct CharactersRepositoryDetailTests {

    @Test("a fresh cache entry answers without touching the network")
    func freshCacheSkipsTheNetwork() async throws {
        let local = FakeCharactersLocalDataSource(detailEntry: .fresh(detail: .make(name: "Rick Sanchez")))
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .success(.make(name: "From network")))
        let repository = makeCharactersRepository(remote: remote, local: local)

        let detail = try await repository.fetchCharacterDetail(id: "1")

        #expect(detail.name == "Rick Sanchez")
        #expect(await remote.detailCallCount == 0)
    }

    @Test("an expired entry is refreshed from the network and written back")
    func expiredCacheRefetchesAndStores() async throws {
        let local = FakeCharactersLocalDataSource(detailEntry: .expired(detail: .make(name: "Yesterday")))
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .success(.make(name: "Rick Sanchez")))
        let repository = makeCharactersRepository(remote: remote, local: local)

        let detail = try await repository.fetchCharacterDetail(id: "1")

        #expect(detail.name == "Rick Sanchez")
        #expect(await remote.detailCallCount == 1)
        #expect(await local.storedDetails.first?.name == "Rick Sanchez")
    }

    @Test("a failed refresh falls back to the stale entry")
    func staleEntrySurvivesAFailedFetch() async throws {
        let local = FakeCharactersLocalDataSource(detailEntry: .expired(detail: .make(name: "Yesterday")))
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .failure(TestError()))
        let repository = makeCharactersRepository(remote: remote, local: local)

        #expect(try await repository.fetchCharacterDetail(id: "1").name == "Yesterday")
    }

    @Test("with nothing cached, a failed fetch is an error")
    func noCacheAndFailedFetchThrows() async {
        let local = FakeCharactersLocalDataSource()
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .failure(TestError()))
        let repository = makeCharactersRepository(remote: remote, local: local)

        await #expect(throws: TestError.self) {
            _ = try await repository.fetchCharacterDetail(id: "1")
        }
    }

    @Test("a cache read that throws is a miss, not a failure")
    func cacheReadFailureFallsThroughToTheNetwork() async throws {
        let local = FakeCharactersLocalDataSource(readError: TestError())
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .success(.make(name: "Rick Sanchez")))
        let repository = makeCharactersRepository(remote: remote, local: local)

        #expect(try await repository.fetchCharacterDetail(id: "1").name == "Rick Sanchez")
        #expect(await remote.detailCallCount == 1)
    }

    @Test("a cache write that throws still returns the fetched detail")
    func cacheWriteFailureDoesNotFailTheFetch() async throws {
        let local = FakeCharactersLocalDataSource(writeError: TestError())
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .success(.make(name: "Rick Sanchez")))
        let repository = makeCharactersRepository(remote: remote, local: local)

        #expect(try await repository.fetchCharacterDetail(id: "1").name == "Rick Sanchez")
    }

    @Test("cancellation is rethrown rather than answered from a stale entry")
    func cancellationIsRethrown() async {
        let local = FakeCharactersLocalDataSource(detailEntry: .expired(detail: .make(name: "Yesterday")))
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .failure(CancellationError()))
        let repository = makeCharactersRepository(remote: remote, local: local)

        await #expect(throws: CancellationError.self) {
            _ = try await repository.fetchCharacterDetail(id: "1")
        }
    }

    /// The id has to reach the query, or every detail on the screen is whichever
    /// character the server happens to answer with.
    @Test("the id reaches the query")
    func theIdReachesTheQuery() async throws {
        let local = FakeCharactersLocalDataSource()
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .success(.make(id: "42")))
        let repository = makeCharactersRepository(remote: remote, local: local)

        _ = try await repository.fetchCharacterDetail(id: "42")

        #expect(await remote.lastDetailQuery?.id == "42")
    }

    /// The one place the detail is stricter than the list. An unmappable
    /// character in a page is a skipped row; here it is the entire screen, and a
    /// half-drawn page would be worse than an error the user can retry.
    @Test("a detail that cannot be mapped throws rather than rendering half a screen")
    func unmappableDetailThrows() async {
        let local = FakeCharactersLocalDataSource(detailEntry: .fresh(detail: .make(image: nil)))
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .failure(TestError()))
        let repository = makeCharactersRepository(remote: remote, local: local)

        await #expect(throws: CharacterDetailEntityMapperError.self) {
            _ = try await repository.fetchCharacterDetail(id: "1")
        }
    }

    /// The episodes are the exception inside the exception: one that will not
    /// map costs its own row and nothing else, because a filmography missing an
    /// entry is invisible while a blank screen is not.
    @Test("one unmappable episode is skipped, not fatal to the detail")
    func unmappableEpisodesAreSkipped() async throws {
        let entity = CharacterDetailEntity.make(episodes: [
            CharacterDetailEpisode(id: "1", name: "Pilot", air_date: "December 2, 2013", episode: "S01E01"),
            CharacterDetailEpisode(id: "2", name: "Broken", air_date: nil, episode: "nonsense")
        ])
        let local = FakeCharactersLocalDataSource(detailEntry: .fresh(detail: entity))
        let remote = FakeCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .failure(TestError()))
        let repository = makeCharactersRepository(remote: remote, local: local)

        #expect(try await repository.fetchCharacterDetail(id: "1").episodes.map(\.name) == ["Pilot"])
    }
}

// MARK: - The HBO Max links

/// The third request through the same four steps, and the only one that goes to
/// a server this app has no relationship with. The policy does not change for
/// it; what changes is what the caller does with a failure, and that is the use
/// case's business rather than this layer's.
@Suite("CharactersRepository: the HBO Max links")
struct CharactersRepositoryHBOMaxLinksTests {

    @Test("a fresh cache entry answers without touching JustWatch")
    func freshCacheSkipsTheNetwork() async throws {
        let local = FakeCharactersLocalDataSource(
            offersEntry: .fresh(offers: .oneEpisode(link: "https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444"))
        )
        let links = FakeCharactersHBOMaxLinksRemoteDataSource(result: .failure(TestError()))
        let repository = makeCharactersRepository(local: local, links: links)

        let fetched = try await repository.fetchHBOMaxLinks()

        #expect(fetched.url(season: 1, number: 1)?.absoluteString.contains("aaaaaaaa") == true)
        #expect(await links.callCount == 0)
    }

    @Test("an expired entry is refreshed from JustWatch and written back")
    func expiredCacheRefetchesAndStores() async throws {
        let local = FakeCharactersLocalDataSource(offersEntry: .expired(offers: JustWatchShowEntity(seasons: nil)))
        let links = FakeCharactersHBOMaxLinksRemoteDataSource(
            result: .success(.oneEpisode(link: "https://play.hbomax.com/video/watch/bbbbbbbb-1111-2222-3333-444444444444"))
        )
        let repository = makeCharactersRepository(local: local, links: links)

        let fetched = try await repository.fetchHBOMaxLinks()

        #expect(fetched.url(season: 1, number: 1)?.absoluteString.contains("bbbbbbbb") == true)
        #expect(await links.callCount == 1)
        #expect(await local.storedOffers.count == 1)
    }

    @Test("a failed refresh falls back to the stale entry")
    func staleEntrySurvivesAFailedFetch() async throws {
        let local = FakeCharactersLocalDataSource(
            offersEntry: .expired(offers: .oneEpisode(link: "https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444"))
        )
        let repository = makeCharactersRepository(local: local,
                                                  links: FakeCharactersHBOMaxLinksRemoteDataSource(result: .failure(TestError())))

        #expect(try await repository.fetchHBOMaxLinks().url(season: 1, number: 1) != nil)
    }

    @Test("with nothing cached, a failed lookup is an error")
    func noCacheAndFailedFetchThrows() async {
        let repository = makeCharactersRepository(local: FakeCharactersLocalDataSource(),
                                                  links: FakeCharactersHBOMaxLinksRemoteDataSource(result: .failure(TestError())))

        await #expect(throws: TestError.self) {
            _ = try await repository.fetchHBOMaxLinks()
        }
    }

    @Test("a cache read that throws is a miss, not a failure")
    func cacheReadFailureFallsThroughToTheNetwork() async throws {
        let local = FakeCharactersLocalDataSource(readError: TestError())
        let links = FakeCharactersHBOMaxLinksRemoteDataSource(
            result: .success(.oneEpisode(link: "https://play.hbomax.com/video/watch/bbbbbbbb-1111-2222-3333-444444444444"))
        )

        #expect(try await makeCharactersRepository(local: local, links: links)
            .fetchHBOMaxLinks().url(season: 1, number: 1) != nil)
    }

    @Test("a cache write that throws still returns the fetched links")
    func cacheWriteFailureDoesNotFailTheFetch() async throws {
        let local = FakeCharactersLocalDataSource(writeError: TestError())
        let links = FakeCharactersHBOMaxLinksRemoteDataSource(
            result: .success(.oneEpisode(link: "https://play.hbomax.com/video/watch/bbbbbbbb-1111-2222-3333-444444444444"))
        )

        #expect(try await makeCharactersRepository(local: local, links: links)
            .fetchHBOMaxLinks().url(season: 1, number: 1) != nil)
    }

    @Test("cancellation is rethrown rather than answered from a stale entry")
    func cancellationIsRethrown() async {
        let local = FakeCharactersLocalDataSource(
            offersEntry: .expired(offers: .oneEpisode(link: "https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444"))
        )
        let repository = makeCharactersRepository(local: local,
                                                  links: FakeCharactersHBOMaxLinksRemoteDataSource(result: .failure(CancellationError())))

        await #expect(throws: CancellationError.self) {
            _ = try await repository.fetchHBOMaxLinks()
        }
    }

    /// A response with nothing usable in it is not a failure: it is a screen
    /// with no play buttons, which is exactly what an episode HBO Max does not
    /// carry looks like.
    @Test("an unhelpful response is an empty set of links, not an error")
    func anEmptyResponseIsEmptyLinks() async throws {
        let local = FakeCharactersLocalDataSource(offersEntry: .fresh(offers: JustWatchShowEntity(seasons: nil)))

        #expect(try await makeCharactersRepository(local: local).fetchHBOMaxLinks() == .empty)
    }
}

// MARK: - Test doubles

struct TestError: Error, Equatable {}

/// Built here rather than inline in each suite: the repository now takes six
/// collaborators, and four of them are the same real mappers in every test —
/// the policy is what is under test, not the mapping.
func makeCharactersRepository(
    remote: FakeCharactersRemoteDataSource = FakeCharactersRemoteDataSource(result: .failure(TestError())),
    local: FakeCharactersLocalDataSource = FakeCharactersLocalDataSource(),
    links: FakeCharactersHBOMaxLinksRemoteDataSource = FakeCharactersHBOMaxLinksRemoteDataSource()
) -> CharactersRepository {
    CharactersRepository(remoteDataSource: remote,
                         hboMaxLinksRemoteDataSource: links,
                         localDataSource: local,
                         mapper: CharacterEntityMapper(),
                         detailMapper: CharacterDetailEntityMapper(),
                         linksMapper: HBOMaxLinksMapper())
}

actor FakeCharactersRemoteDataSource: CharactersRemoteDataSourceContract {
    private let result: Result<CharactersPageEntity, any Error>
    private let detailResult: Result<CharacterDetailEntity, any Error>
    private(set) var callCount = 0
    private(set) var detailCallCount = 0
    /// The query as the repository built it. Recording it is the only way to
    /// check the filter mapping without reaching into the repository: the query
    /// is a private local, and the network is where it becomes observable.
    private(set) var lastQuery: CharactersQuery?
    private(set) var lastDetailQuery: CharacterDetailQuery?

    init(result: Result<CharactersPageEntity, any Error>,
         detailResult: Result<CharacterDetailEntity, any Error> = .failure(TestError())) {
        self.result = result
        self.detailResult = detailResult
    }

    func fetchCharactersPage(_ query: CharactersQuery) async throws -> CharactersPageEntity {
        callCount += 1
        lastQuery = query
        return try result.get()
    }

    func fetchCharacterDetail(_ query: CharacterDetailQuery) async throws -> CharacterDetailEntity {
        detailCallCount += 1
        lastDetailQuery = query
        return try detailResult.get()
    }
}

actor FakeCharactersLocalDataSource: CharactersLocalDataSourceContract {
    private let entry: CacheEntry<CharactersPageEntity>?
    private let detailEntry: CacheEntry<CharacterDetailEntity>?
    /// There is only ever one offers entry — the lookup is one request for the
    /// whole show — so it needs no key.
    private let offersEntry: CacheEntry<JustWatchShowEntity>?
    private let readError: (any Error)?
    private let writeError: (any Error)?
    private(set) var storedPages: [CharactersPageEntity] = []
    private(set) var storedDetails: [CharacterDetailEntity] = []
    private(set) var storedOffers: [JustWatchShowEntity] = []
    private(set) var removeAllCallCount = 0

    init(entry: CacheEntry<CharactersPageEntity>? = nil,
         detailEntry: CacheEntry<CharacterDetailEntity>? = nil,
         offersEntry: CacheEntry<JustWatchShowEntity>? = nil,
         readError: (any Error)? = nil,
         writeError: (any Error)? = nil) {
        self.entry = entry
        self.detailEntry = detailEntry
        self.offersEntry = offersEntry
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
        return detailEntry
    }

    func store(_ detail: CharacterDetailEntity, for query: CharacterDetailQuery) async throws {
        if let writeError { throw writeError }
        storedDetails.append(detail)
    }

    func showOffers(for query: JustWatchShowOffersQuery) async throws -> CacheEntry<JustWatchShowEntity>? {
        if let readError { throw readError }
        return offersEntry
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

/// One canned answer, because the lookup is one request: there is no page, no
/// filter and no second call to tell apart.
actor FakeCharactersHBOMaxLinksRemoteDataSource: HBOMaxLinksRemoteDataSourceContract {
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

extension CacheEntry where Value == CharactersPageEntity {
    static func fresh(page: CharactersPageEntity) -> CacheEntry {
        CacheEntry(value: page, storedAt: .distantPast, expiresAt: .distantFuture, isExpired: false)
    }

    static func expired(page: CharactersPageEntity) -> CacheEntry {
        CacheEntry(value: page, storedAt: .distantPast, expiresAt: .distantPast, isExpired: true)
    }
}

extension CacheEntry where Value == CharacterDetailEntity {
    static func fresh(detail: CharacterDetailEntity) -> CacheEntry {
        CacheEntry(value: detail, storedAt: .distantPast, expiresAt: .distantFuture, isExpired: false)
    }

    static func expired(detail: CharacterDetailEntity) -> CacheEntry {
        CacheEntry(value: detail, storedAt: .distantPast, expiresAt: .distantPast, isExpired: true)
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
    /// Season 1, episode 1, on HBO Max at `link`. The policy tests only ever
    /// need to tell one answer from another.
    static func oneEpisode(link: String) -> JustWatchShowEntity {
        .make(episodes: [.make(season: 1, number: 1, offers: [.max(link)])])
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

extension CharacterDetailEntity {
    /// Every property defaults to something valid, so a test that is about one
    /// missing field says only that.
    static func make(id: String? = "1",
                     name: String? = "Rick Sanchez",
                     status: String? = "Alive",
                     species: String? = "Human",
                     type: String? = "",
                     gender: String? = "Male",
                     origin: CharacterDetailPlace? = CharacterDetailPlace(id: "1",
                                                                         name: "Earth (C-137)",
                                                                         type: "Planet",
                                                                         dimension: "Dimension C-137"),
                     location: CharacterDetailPlace? = CharacterDetailPlace(id: "3",
                                                                           name: "Citadel of Ricks",
                                                                           type: "Space station",
                                                                           dimension: "unknown"),
                     image: URL? = URL(string: "https://example.com/1.jpeg"),
                     episodes: [CharacterDetailEpisode]? = [
                        CharacterDetailEpisode(id: "1", name: "Pilot",
                                               air_date: "December 2, 2013", episode: "S01E01"),
                        CharacterDetailEpisode(id: "2", name: "Lawnmower Dog",
                                               air_date: "December 9, 2013", episode: "S01E02")
                     ]) -> CharacterDetailEntity {
        CharacterDetailEntity(id: id,
                              name: name,
                              status: status,
                              species: species,
                              type: type,
                              gender: gender,
                              origin: origin,
                              location: location,
                              image: image,
                              episode: episodes)
    }
}
