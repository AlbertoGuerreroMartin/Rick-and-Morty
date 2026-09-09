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

@Suite("CharactersRepository")
struct CharactersRepositoryTests {

    @Test("a fresh cache entry answers without touching the network")
    func freshCacheSkipsTheNetwork() async throws {
        let local = StubCharactersLocalDataSource(entry: .fresh(page: .make(names: ["Rick Sanchez"])))
        let remote = StubCharactersRemoteDataSource(result: .success(.make(names: ["From network"])))
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchCharacters(filter: .empty, page: 1)

        #expect(page.characters.map(\.name) == ["Rick Sanchez"])
        #expect(await remote.callCount == 0)
    }

    @Test("an expired entry is refreshed from the network and written back")
    func expiredCacheRefetchesAndStores() async throws {
        let local = StubCharactersLocalDataSource(entry: .expired(page: .make(names: ["Yesterday"])))
        let remote = StubCharactersRemoteDataSource(result: .success(.make(names: ["Rick Sanchez"])))
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchCharacters(filter: .empty, page: 1)

        #expect(page.characters.map(\.name) == ["Rick Sanchez"])
        #expect(await remote.callCount == 1)
        #expect(await local.storedPages.first?.results.first?.name == "Rick Sanchez")
    }

    @Test("a failed refresh falls back to the stale entry")
    func staleEntrySurvivesAFailedFetch() async throws {
        let local = StubCharactersLocalDataSource(entry: .expired(page: .make(names: ["Yesterday"])))
        let remote = StubCharactersRemoteDataSource(result: .failure(TestError()))
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchCharacters(filter: .empty, page: 1)

        #expect(page.characters.map(\.name) == ["Yesterday"])
    }

    @Test("with nothing cached, a failed fetch is an error")
    func noCacheAndFailedFetchThrows() async {
        let local = StubCharactersLocalDataSource(entry: nil)
        let remote = StubCharactersRemoteDataSource(result: .failure(TestError()))
        let repository = makeRepository(remote: remote, local: local)

        await #expect(throws: TestError.self) {
            _ = try await repository.fetchCharacters(filter: .empty, page: 1)
        }
    }

    @Test("a cache read that throws is a miss, not a failure")
    func cacheReadFailureFallsThroughToTheNetwork() async throws {
        let local = StubCharactersLocalDataSource(readError: TestError())
        let remote = StubCharactersRemoteDataSource(result: .success(.make(names: ["Rick Sanchez"])))
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchCharacters(filter: .empty, page: 1)

        #expect(page.characters.map(\.name) == ["Rick Sanchez"])
        #expect(await remote.callCount == 1)
    }

    @Test("a cache write that throws still returns the fetched page")
    func cacheWriteFailureDoesNotFailTheFetch() async throws {
        let local = StubCharactersLocalDataSource(entry: nil, writeError: TestError())
        let remote = StubCharactersRemoteDataSource(result: .success(.make(names: ["Rick Sanchez"])))
        let repository = makeRepository(remote: remote, local: local)

        let page = try await repository.fetchCharacters(filter: .empty, page: 1)

        #expect(page.characters.map(\.name) == ["Rick Sanchez"])
    }

    @Test("cancellation is rethrown rather than answered from a stale entry")
    func cancellationIsRethrown() async {
        let local = StubCharactersLocalDataSource(entry: .expired(page: .make(names: ["Yesterday"])))
        let remote = StubCharactersRemoteDataSource(result: .failure(CancellationError()))
        let repository = makeRepository(remote: remote, local: local)

        await #expect(throws: CancellationError.self) {
            _ = try await repository.fetchCharacters(filter: .empty, page: 1)
        }
    }

    @Test("nextPage comes straight off the page info")
    func nextPageIsCarriedThrough() async throws {
        let local = StubCharactersLocalDataSource(entry: .fresh(page: .make(names: ["Rick"], next: 2)))
        let remote = StubCharactersRemoteDataSource(result: .failure(TestError()))
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
        let local = StubCharactersLocalDataSource(entry: .fresh(page: page))
        let remote = StubCharactersRemoteDataSource(result: .failure(TestError()))
        let repository = makeRepository(remote: remote, local: local)

        #expect(try await repository.fetchCharacters(filter: .empty, page: 1).characters.map(\.name) == ["Rick Sanchez"])
    }

    @Test("every filter field reaches the query")
    func filterFieldsReachTheQuery() async throws {
        let local = StubCharactersLocalDataSource(entry: nil)
        let remote = StubCharactersRemoteDataSource(result: .success(.make(names: ["Rick Sanchez"])))
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

    /// The cache key drops `nil` optionals, so an unfiltered query's identity is unchanged.
    @Test("an empty filter builds exactly the unfiltered query")
    func emptyFilterKeepsTheUnfilteredCacheIdentity() async throws {
        let local = StubCharactersLocalDataSource(entry: nil)
        let remote = StubCharactersRemoteDataSource(result: .success(.make(names: ["Rick Sanchez"])))
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

    private func makeRepository(remote: StubCharactersRemoteDataSource,
                                local: StubCharactersLocalDataSource) -> CharactersRepository {
        makeCharactersRepository(remote: remote, local: local)
    }
}

// MARK: - The character detail

@Suite("CharactersRepository: the character detail")
struct CharactersRepositoryDetailTests {

    @Test("a fresh cache entry answers without touching the network")
    func freshCacheSkipsTheNetwork() async throws {
        let local = StubCharactersLocalDataSource(detailEntry: .fresh(detail: .make(name: "Rick Sanchez")))
        let remote = StubCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .success(.make(name: "From network")))
        let repository = makeCharactersRepository(remote: remote, local: local)

        let detail = try await repository.fetchCharacterDetail(id: "1")

        #expect(detail.name == "Rick Sanchez")
        #expect(await remote.detailCallCount == 0)
    }

    @Test("an expired entry is refreshed from the network and written back")
    func expiredCacheRefetchesAndStores() async throws {
        let local = StubCharactersLocalDataSource(detailEntry: .expired(detail: .make(name: "Yesterday")))
        let remote = StubCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .success(.make(name: "Rick Sanchez")))
        let repository = makeCharactersRepository(remote: remote, local: local)

        let detail = try await repository.fetchCharacterDetail(id: "1")

        #expect(detail.name == "Rick Sanchez")
        #expect(await remote.detailCallCount == 1)
        #expect(await local.storedDetails.first?.name == "Rick Sanchez")
    }

    @Test("a failed refresh falls back to the stale entry")
    func staleEntrySurvivesAFailedFetch() async throws {
        let local = StubCharactersLocalDataSource(detailEntry: .expired(detail: .make(name: "Yesterday")))
        let remote = StubCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .failure(TestError()))
        let repository = makeCharactersRepository(remote: remote, local: local)

        #expect(try await repository.fetchCharacterDetail(id: "1").name == "Yesterday")
    }

    @Test("with nothing cached, a failed fetch is an error")
    func noCacheAndFailedFetchThrows() async {
        let local = StubCharactersLocalDataSource()
        let remote = StubCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .failure(TestError()))
        let repository = makeCharactersRepository(remote: remote, local: local)

        await #expect(throws: TestError.self) {
            _ = try await repository.fetchCharacterDetail(id: "1")
        }
    }

    @Test("a cache read that throws is a miss, not a failure")
    func cacheReadFailureFallsThroughToTheNetwork() async throws {
        let local = StubCharactersLocalDataSource(readError: TestError())
        let remote = StubCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .success(.make(name: "Rick Sanchez")))
        let repository = makeCharactersRepository(remote: remote, local: local)

        #expect(try await repository.fetchCharacterDetail(id: "1").name == "Rick Sanchez")
        #expect(await remote.detailCallCount == 1)
    }

    @Test("a cache write that throws still returns the fetched detail")
    func cacheWriteFailureDoesNotFailTheFetch() async throws {
        let local = StubCharactersLocalDataSource(writeError: TestError())
        let remote = StubCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .success(.make(name: "Rick Sanchez")))
        let repository = makeCharactersRepository(remote: remote, local: local)

        #expect(try await repository.fetchCharacterDetail(id: "1").name == "Rick Sanchez")
    }

    @Test("cancellation is rethrown rather than answered from a stale entry")
    func cancellationIsRethrown() async {
        let local = StubCharactersLocalDataSource(detailEntry: .expired(detail: .make(name: "Yesterday")))
        let remote = StubCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .failure(CancellationError()))
        let repository = makeCharactersRepository(remote: remote, local: local)

        await #expect(throws: CancellationError.self) {
            _ = try await repository.fetchCharacterDetail(id: "1")
        }
    }

    @Test("the id reaches the query")
    func theIdReachesTheQuery() async throws {
        let local = StubCharactersLocalDataSource()
        let remote = StubCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .success(.make(id: "42")))
        let repository = makeCharactersRepository(remote: remote, local: local)

        _ = try await repository.fetchCharacterDetail(id: "42")

        #expect(await remote.lastDetailQuery?.id == "42")
    }

    @Test("a detail that cannot be mapped throws rather than rendering half a screen")
    func unmappableDetailThrows() async {
        let local = StubCharactersLocalDataSource(detailEntry: .fresh(detail: .make(image: nil)))
        let remote = StubCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .failure(TestError()))
        let repository = makeCharactersRepository(remote: remote, local: local)

        await #expect(throws: CharacterDetailEntityMapperError.self) {
            _ = try await repository.fetchCharacterDetail(id: "1")
        }
    }

    @Test("one unmappable episode is skipped, not fatal to the detail")
    func unmappableEpisodesAreSkipped() async throws {
        let entity = CharacterDetailEntity.make(episodes: [
            CharacterDetailEpisode(id: "1", name: "Pilot", air_date: "December 2, 2013", episode: "S01E01"),
            CharacterDetailEpisode(id: "2", name: "Broken", air_date: nil, episode: "nonsense")
        ])
        let local = StubCharactersLocalDataSource(detailEntry: .fresh(detail: entity))
        let remote = StubCharactersRemoteDataSource(result: .failure(TestError()),
                                                    detailResult: .failure(TestError()))
        let repository = makeCharactersRepository(remote: remote, local: local)

        #expect(try await repository.fetchCharacterDetail(id: "1").episodes.map(\.name) == ["Pilot"])
    }
}

// MARK: - The HBO Max links

@Suite("CharactersRepository: the HBO Max links")
struct CharactersRepositoryHBOMaxLinksTests {

    @Test("a fresh cache entry answers without touching JustWatch")
    func freshCacheSkipsTheNetwork() async throws {
        let local = StubCharactersLocalDataSource(
            offersEntry: .fresh(offers: .oneEpisode(link: "https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444"))
        )
        let links = StubCharactersHBOMaxLinksRemoteDataSource(result: .failure(TestError()))
        let repository = makeCharactersRepository(local: local, links: links)

        let fetched = try await repository.fetchHBOMaxLinks()

        #expect(fetched.url(season: 1, number: 1)?.absoluteString.contains("aaaaaaaa") == true)
        #expect(await links.callCount == 0)
    }

    @Test("an expired entry is refreshed from JustWatch and written back")
    func expiredCacheRefetchesAndStores() async throws {
        let local = StubCharactersLocalDataSource(offersEntry: .expired(offers: JustWatchShowEntity(seasons: nil)))
        let links = StubCharactersHBOMaxLinksRemoteDataSource(
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
        let local = StubCharactersLocalDataSource(
            offersEntry: .expired(offers: .oneEpisode(link: "https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444"))
        )
        let repository = makeCharactersRepository(local: local,
                                                  links: StubCharactersHBOMaxLinksRemoteDataSource(result: .failure(TestError())))

        #expect(try await repository.fetchHBOMaxLinks().url(season: 1, number: 1) != nil)
    }

    @Test("with nothing cached, a failed lookup is an error")
    func noCacheAndFailedFetchThrows() async {
        let repository = makeCharactersRepository(local: StubCharactersLocalDataSource(),
                                                  links: StubCharactersHBOMaxLinksRemoteDataSource(result: .failure(TestError())))

        await #expect(throws: TestError.self) {
            _ = try await repository.fetchHBOMaxLinks()
        }
    }

    @Test("a cache read that throws is a miss, not a failure")
    func cacheReadFailureFallsThroughToTheNetwork() async throws {
        let local = StubCharactersLocalDataSource(readError: TestError())
        let links = StubCharactersHBOMaxLinksRemoteDataSource(
            result: .success(.oneEpisode(link: "https://play.hbomax.com/video/watch/bbbbbbbb-1111-2222-3333-444444444444"))
        )

        #expect(try await makeCharactersRepository(local: local, links: links)
            .fetchHBOMaxLinks().url(season: 1, number: 1) != nil)
    }

    @Test("a cache write that throws still returns the fetched links")
    func cacheWriteFailureDoesNotFailTheFetch() async throws {
        let local = StubCharactersLocalDataSource(writeError: TestError())
        let links = StubCharactersHBOMaxLinksRemoteDataSource(
            result: .success(.oneEpisode(link: "https://play.hbomax.com/video/watch/bbbbbbbb-1111-2222-3333-444444444444"))
        )

        #expect(try await makeCharactersRepository(local: local, links: links)
            .fetchHBOMaxLinks().url(season: 1, number: 1) != nil)
    }

    @Test("cancellation is rethrown rather than answered from a stale entry")
    func cancellationIsRethrown() async {
        let local = StubCharactersLocalDataSource(
            offersEntry: .expired(offers: .oneEpisode(link: "https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444"))
        )
        let repository = makeCharactersRepository(local: local,
                                                  links: StubCharactersHBOMaxLinksRemoteDataSource(result: .failure(CancellationError())))

        await #expect(throws: CancellationError.self) {
            _ = try await repository.fetchHBOMaxLinks()
        }
    }

    @Test("an unhelpful response is an empty set of links, not an error")
    func anEmptyResponseIsEmptyLinks() async throws {
        let local = StubCharactersLocalDataSource(offersEntry: .fresh(offers: JustWatchShowEntity(seasons: nil)))

        #expect(try await makeCharactersRepository(local: local).fetchHBOMaxLinks() == .empty)
    }
}

// MARK: - Test doubles

func makeCharactersRepository(
    remote: StubCharactersRemoteDataSource = StubCharactersRemoteDataSource(result: .failure(TestError())),
    local: StubCharactersLocalDataSource = StubCharactersLocalDataSource(),
    links: StubCharactersHBOMaxLinksRemoteDataSource = StubCharactersHBOMaxLinksRemoteDataSource()
) -> CharactersRepository {
    CharactersRepository(remoteDataSource: remote,
                         hboMaxLinksRemoteDataSource: links,
                         localDataSource: local,
                         mapper: CharacterEntityMapper(),
                         detailMapper: CharacterDetailEntityMapper(),
                         linksMapper: HBOMaxLinksMapper())
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
    /// Season 1, episode 1, on HBO Max at `link`.
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
