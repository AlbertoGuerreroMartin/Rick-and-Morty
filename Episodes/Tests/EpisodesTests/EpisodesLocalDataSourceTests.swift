//
//  EpisodesLocalDataSourceTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Storage
import Testing
@testable import Episodes

/// Run against the real `CodableCacheStore` on a real `FileDiskStore`, so an entity round trips
/// through the actual encoder and filesystem.
@Suite("EpisodesLocalDataSource")
struct EpisodesLocalDataSourceTests {

    @Test("a page round trips through disk")
    func pageRoundTrip() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)
        let query = EpisodesQuery(page: 1)

        try await dataSource.store(.make(codes: ["S01E01", "S01E02"], next: 2, pages: 3), for: query)
        let entry = try await dataSource.episodesPage(for: query)

        #expect(entry?.value.results.map(\.episode) == ["S01E01", "S01E02"])
        #expect(entry?.value.results.first?.characters?.map(\.id) == ["1", "2"])
        #expect(entry?.value.info.next == 2)
        #expect(entry?.value.info.pages == 3)
        #expect(entry?.isExpired == false)
    }

    @Test("a page that was never stored reads as nil")
    func missingPageIsNil() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)

        #expect(try await dataSource.episodesPage(for: EpisodesQuery(page: 9)) == nil)
    }

    @Test("two pages of the same query are two entries")
    func pagesGetDifferentKeys() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)

        try await dataSource.store(.make(codes: ["S01E01"]), for: EpisodesQuery(page: 1))
        try await dataSource.store(.make(codes: ["S02E01"]), for: EpisodesQuery(page: 2))

        #expect(try await dataSource.episodesPage(for: EpisodesQuery(page: 1))?
            .value.results.map(\.episode) == ["S01E01"])
        #expect(try await dataSource.episodesPage(for: EpisodesQuery(page: 2))?
            .value.results.map(\.episode) == ["S02E01"])
    }

    @Test("removeAll forgets every page")
    func removeAllForgetsEverything() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)
        try await dataSource.store(.make(codes: ["S01E01"]), for: EpisodesQuery(page: 1))
        try await dataSource.store(.make(codes: ["S02E01"]), for: EpisodesQuery(page: 2))

        try await dataSource.removeAll()

        #expect(try await dataSource.episodesPage(for: EpisodesQuery(page: 1)) == nil)
        #expect(try await dataSource.episodesPage(for: EpisodesQuery(page: 2)) == nil)
    }

    @Test("purging through the factory empties the feature's cache")
    func purgeCacheEmptiesTheFeature() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dependencies = PurgeTestEpisodesDependencies(root: directory.url)
        let dataSource = EpisodesLocalDataSource(cacheStore: dependencies.cacheStore)
        try await dataSource.store(.make(codes: ["S01E01"]), for: EpisodesQuery(page: 1))

        try await EpisodesFactory.purgeCache(dependencies: dependencies)

        #expect(try await dataSource.episodesPage(for: EpisodesQuery(page: 1)) == nil)
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

    @Test("the offers and a page of episodes are two entries")
    func offersDoNotCollideWithAPage() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)

        try await dataSource.store(.make(codes: ["S01E01"]), for: EpisodesQuery(page: 1))
        try await dataSource.store(.oneEpisode(link: "https://play.hbomax.com/video/watch/1"), for: JustWatchShowOffersQuery())

        #expect(try await dataSource.episodesPage(for: EpisodesQuery(page: 1))?
            .value.results.map(\.episode) == ["S01E01"])
        #expect(try await dataSource.showOffers(for: JustWatchShowOffersQuery())?
            .value.seasons?.count == 1)
    }

    @Test("removeAll forgets the offers too")
    func removeAllForgetsTheOffers() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)
        try await dataSource.store(.make(codes: ["S01E01"]), for: EpisodesQuery(page: 1))
        try await dataSource.store(.oneEpisode(link: "https://play.hbomax.com/video/watch/1"), for: JustWatchShowOffersQuery())

        try await dataSource.removeAll()

        #expect(try await dataSource.episodesPage(for: EpisodesQuery(page: 1)) == nil)
        #expect(try await dataSource.showOffers(for: JustWatchShowOffersQuery()) == nil)
    }

    @Test("the lifetime is a week")
    func lifetimeIsSevenDays() {
        #expect(EpisodesLocalDataSource.lifetime == 7 * 24 * 60 * 60)
    }

    private func makeDataSource(root: URL) -> EpisodesLocalDataSource {
        EpisodesLocalDataSource(cacheStore: CodableCacheStore(diskStore: FileDiskStore(root: root)))
    }
}

/// Stands in for the app container; `purgeCache` only touches the cache store.
private struct PurgeTestEpisodesDependencies: EpisodesDependencies {
    let graphQLClient = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!)
    let justWatchClient = GraphQLClient(endpoint: URL(string: "https://example.com/justwatch")!)
    let cacheStore: any CacheStoreContract

    init(root: URL) {
        cacheStore = CodableCacheStore(diskStore: FileDiskStore(root: root))
    }
}

/// A unique directory per test so tests cannot see each other's files.
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
