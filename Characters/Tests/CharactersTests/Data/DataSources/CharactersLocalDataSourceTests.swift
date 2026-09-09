//
//  CharactersLocalDataSourceTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Core
import Foundation
import Storage
import Testing
@testable import Characters

@Suite("CharactersLocalDataSource")
struct CharactersLocalDataSourceTests {

    @Test("a page round trips through disk")
    func pageRoundTrip() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)
        let query = CharactersQuery(page: 1)

        try await dataSource.store(.make(names: ["Rick Sanchez", "Morty Smith"], next: 2), for: query)
        let entry = try await dataSource.charactersPage(for: query)

        #expect(entry?.value.results.map(\.name) == ["Rick Sanchez", "Morty Smith"])
        #expect(entry?.value.info.next == 2)
        #expect(entry?.isExpired == false)
    }

    @Test("a detail round trips through disk")
    func detailRoundTrip() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)
        let query = CharacterDetailQuery(id: "1")
        let rick = CharacterDetailEntity.make()

        try await dataSource.store(rick, for: query)
        let entry = try await dataSource.characterDetail(for: query)

        #expect(entry?.value == rick)
        #expect(entry?.value.episode?.map(\.episode) == ["S01E01", "S01E02"])
        #expect(entry?.value.origin?.type == "Planet")
        #expect(entry?.isExpired == false)
    }

    @Test("two characters are two entries")
    func detailsGetDifferentKeys() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)

        try await dataSource.store(.make(id: "1", name: "Rick Sanchez"), for: CharacterDetailQuery(id: "1"))
        try await dataSource.store(.make(id: "2", name: "Morty Smith"), for: CharacterDetailQuery(id: "2"))

        #expect(try await dataSource.characterDetail(for: CharacterDetailQuery(id: "1"))?.value.name == "Rick Sanchez")
        #expect(try await dataSource.characterDetail(for: CharacterDetailQuery(id: "2"))?.value.name == "Morty Smith")
    }

    @Test("a page that was never stored reads as nil")
    func missingPageIsNil() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)

        #expect(try await dataSource.charactersPage(for: CharactersQuery(page: 9)) == nil)
    }

    @Test("two pages of the same query are two entries")
    func pagesGetDifferentKeys() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)

        try await dataSource.store(.make(names: ["Rick Sanchez"]), for: CharactersQuery(page: 1))
        try await dataSource.store(.make(names: ["Birdperson"]), for: CharactersQuery(page: 2))

        #expect(try await dataSource.charactersPage(for: CharactersQuery(page: 1))?
            .value.results.map(\.name) == ["Rick Sanchez"])
        #expect(try await dataSource.charactersPage(for: CharactersQuery(page: 2))?
            .value.results.map(\.name) == ["Birdperson"])
    }

    @Test("a list query and a detail query never collide")
    func listAndDetailGetDifferentKeys() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)

        try await dataSource.store(.make(names: ["Rick Sanchez"]), for: CharactersQuery(page: 1))

        #expect(try await dataSource.characterDetail(for: CharacterDetailQuery(id: "1")) == nil)
    }

    @Test("removeAll forgets every page and detail")
    func removeAllForgetsEverything() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)
        let page = CharactersQuery(page: 1)
        let detail = CharacterDetailQuery(id: "1")
        let offers = JustWatchShowOffersQuery()
        try await dataSource.store(.make(names: ["Rick Sanchez"]), for: page)
        try await dataSource.store(.make(), for: detail)
        try await dataSource.store(.oneEpisode(link: "https://play.hbomax.com/video/watch/1"), for: offers)

        try await dataSource.removeAll()

        #expect(try await dataSource.charactersPage(for: page) == nil)
        #expect(try await dataSource.characterDetail(for: detail) == nil)
        #expect(try await dataSource.showOffers(for: offers) == nil)
    }

    // MARK: - The JustWatch offers

    @Test("the offers entity round trips through disk")
    func offersRoundTrip() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)
        let query = JustWatchShowOffersQuery()

        try await dataSource.store(.oneEpisode(link: "https://play.hbomax.com/video/watch/1"), for: query)
        let entry = try await dataSource.showOffers(for: query)

        #expect(entry?.value.seasons?.first?.episodes?.first?.content?.episodeNumber == 1)
        #expect(entry?.value.seasons?.first?.episodes?.first?.offers?.first?.deeplinkURL
                == "https://play.hbomax.com/video/watch/1")
        #expect(entry?.isExpired == false)
    }

    @Test("offers that were never stored read as nil")
    func missingOffersAreNil() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)

        #expect(try await dataSource.showOffers(for: JustWatchShowOffersQuery()) == nil)
    }

    @Test("a page, a detail and the offers are three entries")
    func everyQueryGetsItsOwnKey() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)

        try await dataSource.store(.make(names: ["Rick Sanchez"]), for: CharactersQuery(page: 1))
        try await dataSource.store(.make(), for: CharacterDetailQuery(id: "1"))
        try await dataSource.store(.oneEpisode(link: "https://play.hbomax.com/video/watch/1"),
                                   for: JustWatchShowOffersQuery())

        #expect(try await dataSource.charactersPage(for: CharactersQuery(page: 1))?
            .value.results.map(\.name) == ["Rick Sanchez"])
        #expect(try await dataSource.characterDetail(for: CharacterDetailQuery(id: "1"))?.value.name == "Rick Sanchez")
        #expect(try await dataSource.showOffers(for: JustWatchShowOffersQuery())?.value.seasons?.count == 1)
    }

    // MARK: - Lifetimes

    @Test("the offers keep a week and everything else a day")
    func lifetimesAreDistinct() {
        #expect(CharactersLocalDataSource.lifetime == 24 * 60 * 60)
        #expect(CharactersLocalDataSource.offersLifetime == 7 * 24 * 60 * 60)
    }

    @Test("each entry expires on its own clock")
    func lifetimesReachTheStore() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)
        let detail = CharacterDetailQuery(id: "1")
        let offers = JustWatchShowOffersQuery()

        try await dataSource.store(.make(), for: detail)
        try await dataSource.store(.oneEpisode(link: "https://play.hbomax.com/video/watch/1"), for: offers)

        let detailEntry = try #require(try await dataSource.characterDetail(for: detail))
        let offersEntry = try #require(try await dataSource.showOffers(for: offers))

        #expect(detailEntry.expiresAt.timeIntervalSince(detailEntry.storedAt) == CharactersLocalDataSource.lifetime)
        #expect(offersEntry.expiresAt.timeIntervalSince(offersEntry.storedAt) == CharactersLocalDataSource.offersLifetime)
    }

    @Test("purging through the factory empties the feature's cache")
    @MainActor
    func purgeCacheEmptiesTheFeature() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let root = DependencyContainer()
        CharactersAssembly.register(in: root,
                                    dependencies: PurgeTestCharactersDependencies(root: directory.url),
                                    navigator: CharactersNavigator())
        let dataSource = root.resolve((any CharactersLocalDataSourceContract).self)
        let query = CharactersQuery(page: 1)
        try await dataSource.store(.make(names: ["Rick Sanchez"], next: nil), for: query)

        try await CharactersFactory.purgeCache(root: root)

        #expect(try await dataSource.charactersPage(for: query) == nil)
    }

    private func makeDataSource(root: URL) -> CharactersLocalDataSource {
        CharactersLocalDataSource(cacheStore: CodableCacheStore(diskStore: FileDiskStore(root: root)))
    }
}

/// A unique directory per test, so tests never share files with each other or the app's real cache.
struct TemporaryDirectory {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
