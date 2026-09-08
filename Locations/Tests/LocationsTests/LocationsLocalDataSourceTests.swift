//
//  LocationsLocalDataSourceTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation
import Networking
import Storage
import Testing
@testable import Locations

/// Run against the real `CodableCacheStore` on a real `FileDiskStore`: the thing
/// worth checking here is that an entity survives a JSON round trip through the
/// actual encoder and the actual filesystem, which a fake store would not
/// exercise at all.
@Suite("LocationsLocalDataSource")
struct LocationsLocalDataSourceTests {

    @Test("a page round trips through disk")
    func pageRoundTrip() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)
        let query = LocationsQuery(page: 1)

        try await dataSource.store(.make(names: ["Earth", "Abadango"], next: 2), for: query)
        let entry = try await dataSource.locationsPage(for: query)

        #expect(entry?.value.results.map(\.name) == ["Earth", "Abadango"])
        #expect(entry?.value.results.first?.residents?.map(\.id) == ["1", "2"])
        #expect(entry?.value.info.next == 2)
        #expect(entry?.isExpired == false)
    }

    @Test("a page that was never stored reads as nil")
    func missingPageIsNil() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)

        #expect(try await dataSource.locationsPage(for: LocationsQuery(page: 9)) == nil)
    }

    /// The bug this guards against is the expensive one: a single "locations"
    /// key would have page 2 overwrite page 1, and the carousel would then grow
    /// the same twenty circles seven times over.
    @Test("two pages of the same query are two entries")
    func pagesGetDifferentKeys() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)

        try await dataSource.store(.make(names: ["Earth"]), for: LocationsQuery(page: 1))
        try await dataSource.store(.make(names: ["Abadango"]), for: LocationsQuery(page: 2))

        #expect(try await dataSource.locationsPage(for: LocationsQuery(page: 1))?
            .value.results.map(\.name) == ["Earth"])
        #expect(try await dataSource.locationsPage(for: LocationsQuery(page: 2))?
            .value.results.map(\.name) == ["Abadango"])
    }

    @Test("removeAll forgets every page")
    func removeAllForgetsEverything() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)
        try await dataSource.store(.make(names: ["Earth"]), for: LocationsQuery(page: 1))
        try await dataSource.store(.make(names: ["Abadango"]), for: LocationsQuery(page: 2))

        try await dataSource.removeAll()

        #expect(try await dataSource.locationsPage(for: LocationsQuery(page: 1)) == nil)
        #expect(try await dataSource.locationsPage(for: LocationsQuery(page: 2)) == nil)
    }

    /// Not a tautology: seven days is a deliberate choice against the characters
    /// feature's twenty-four hours, and a careless edit back would spend a
    /// request every morning to be told the same 126 rows.
    @Test("the lifetime is a week")
    func lifetimeIsSevenDays() {
        #expect(LocationsLocalDataSource.lifetime == 7 * 24 * 60 * 60)
    }

    private func makeDataSource(root: URL) -> LocationsLocalDataSource {
        LocationsLocalDataSource(cacheStore: CodableCacheStore(diskStore: FileDiskStore(root: root)))
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
