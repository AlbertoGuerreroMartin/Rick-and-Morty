//
//  LocationsLocalDataSourceTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Core
import Foundation
import Networking
import Storage
import Testing
@testable import Locations

/// Run against a real `CodableCacheStore` on a real `FileDiskStore` to exercise the actual
/// JSON round trip and filesystem, not a fake store.
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

    @Test("purging through the factory empties the feature's cache")
    @MainActor
    func purgeCacheEmptiesTheFeature() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dependencies = StubLocationsDependencies(root: directory.url)
        let root = makeRoot(dependencies: dependencies)
        let dataSource = root.resolve((any LocationsLocalDataSourceContract).self)
        try await dataSource.store(.make(names: ["Earth"]), for: LocationsQuery(page: 1))
        try await dataSource.store(.make(names: ["Abadango"]), for: LocationsQuery(page: 2))

        try await LocationsFactory.purgeCache(root: root)

        #expect(try await dataSource.locationsPage(for: LocationsQuery(page: 1)) == nil)
        #expect(try await dataSource.locationsPage(for: LocationsQuery(page: 2)) == nil)
    }

    @Test("purging leaves a sibling namespace alone")
    @MainActor
    func purgeLeavesSiblingsAlone() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dependencies = StubLocationsDependencies(root: directory.url)
        let root = makeRoot(dependencies: dependencies)
        let store = dependencies.cacheStore
        let sibling = CacheKey(namespace: "episodes", identifier: "a-page")
        try await store.store(["S01E01"], for: sibling, lifetime: 60)
        try await root.resolve((any LocationsLocalDataSourceContract).self)
            .store(.make(names: ["Earth"]), for: LocationsQuery(page: 1))

        try await LocationsFactory.purgeCache(root: root)

        #expect(try await store.entry(for: sibling, as: [String].self)?.value == ["S01E01"])
    }

    @Test("the lifetime is a week")
    func lifetimeIsSevenDays() {
        #expect(LocationsLocalDataSource.lifetime == 7 * 24 * 60 * 60)
    }

    /// The real wiring, so the purge goes through the data source the assembly registered.
    @MainActor
    private func makeRoot(dependencies: StubLocationsDependencies) -> DependencyContainer {
        let root = DependencyContainer()
        LocationsAssembly.register(in: root,
                                   dependencies: dependencies,
                                   navigator: LocationsNavigator())
        return root
    }

    private func makeDataSource(root: URL) -> LocationsLocalDataSource {
        LocationsLocalDataSource(cacheStore: CodableCacheStore(diskStore: FileDiskStore(root: root)))
    }
}

/// A unique directory per test, isolated from the app's real cache.
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
