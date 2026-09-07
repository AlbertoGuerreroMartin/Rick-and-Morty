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

/// Run against the real `CodableCacheStore` on a real `FileDiskStore`: the thing
/// worth checking here is that an entity survives a JSON round trip through the
/// actual encoder and the actual filesystem, which a fake store would not
/// exercise at all.
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
        // The bug this guards against is the expensive one: a single "episodes"
        // key would have page 2 overwrite page 1, and the catalogue walk would
        // then serve the same twenty rows three times over.
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

    /// Not a tautology: the number is the one deliberate difference from the
    /// characters feature's cache, and a careless edit back to 24 hours would
    /// triple this screen's request count with nothing on screen to show for it.
    @Test("the lifetime is a week")
    func lifetimeIsSevenDays() {
        #expect(EpisodesLocalDataSource.lifetime == 7 * 24 * 60 * 60)
    }

    private func makeDataSource(root: URL) -> EpisodesLocalDataSource {
        EpisodesLocalDataSource(cacheStore: CodableCacheStore(diskStore: FileDiskStore(root: root)))
    }
}

/// A unique directory per test, so the suite never reads the app's real cache
/// and tests cannot see each other's files.
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
