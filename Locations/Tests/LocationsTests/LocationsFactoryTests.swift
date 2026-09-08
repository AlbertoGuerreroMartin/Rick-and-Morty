//
//  LocationsFactoryTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation
import Networking
import Storage
import Testing
@testable import Locations

/// The factory is the feature's composition root, and every layer it wires is
/// constructor-injected — so building the real graph needs nothing but a client
/// and a cache store, and a missing edge is a compile error here rather than an
/// empty screen at runtime.
@Suite("LocationsFactory")
@MainActor
struct LocationsFactoryTests {

    @Test("the factory builds a graph in its initial state")
    func factoryBuildsTheGraph() {
        let graph = LocationsFactory.makeGraph(dependencies: StubLocationsDependencies())

        #expect(graph.viewModel.locationsPublished == nil)
        #expect(graph.viewModel.loadingPublished == false)
        #expect(graph.viewModel.loadFailedPublished == false)
        #expect(graph.viewModel.selectedLocationIdPublished == nil)
        // Nothing *more* to load before the first page has landed, so the footer
        // stays out of the way.
        #expect(graph.viewModel.paginationPublished == .end)
    }

    /// Both mappers hang off the same view model. A graph that built two of them
    /// would give the carousel and the card two selections that could disagree.
    @Test("both section mappers read the same view model")
    func bothMappersShareTheViewModel() {
        let graph = LocationsFactory.makeGraph(dependencies: StubLocationsDependencies())

        #expect(graph.carouselMapper.viewModel as AnyObject === graph.viewModel)
        #expect(graph.detailMapper.viewModel as AnyObject === graph.viewModel)
    }

    /// The developer-tools screen wipes this feature's cache through the factory,
    /// which is the only way in from outside the module: the namespace stays
    /// private, so a caller cannot name — or mistype — it.
    @Test("purging empties the feature's cache")
    func purgeEmptiesTheCache() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dependencies = StubLocationsDependencies(root: directory.url)
        let dataSource = LocationsLocalDataSource(cacheStore: dependencies.cacheStore)
        try await dataSource.store(.make(names: ["Earth"]), for: LocationsQuery(page: 1))
        try await dataSource.store(.make(names: ["Abadango"]), for: LocationsQuery(page: 2))

        try await LocationsFactory.purgeCache(dependencies: dependencies)

        #expect(try await dataSource.locationsPage(for: LocationsQuery(page: 1)) == nil)
        #expect(try await dataSource.locationsPage(for: LocationsQuery(page: 2)) == nil)
    }

    /// The namespace is what makes the purge one call *and* what keeps it inside
    /// this feature: "Clear Locations" must not take the episodes with it.
    @Test("purging leaves a sibling namespace alone")
    func purgeLeavesSiblingsAlone() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dependencies = StubLocationsDependencies(root: directory.url)
        let store = dependencies.cacheStore
        let sibling = CacheKey(namespace: "episodes", identifier: "a-page")
        try await store.store(["S01E01"], for: sibling, lifetime: 60)
        try await LocationsLocalDataSource(cacheStore: store)
            .store(.make(names: ["Earth"]), for: LocationsQuery(page: 1))

        try await LocationsFactory.purgeCache(dependencies: dependencies)

        #expect(try await store.entry(for: sibling, as: [String].self)?.value == ["S01E01"])
    }
}

/// Stands in for the app container. Nothing here reaches the network, so an
/// endpoint that resolves to nothing is exactly right — the point is that the
/// factory can be handed the two things it declares and nothing else.
struct StubLocationsDependencies: LocationsDependencies {
    let graphQLClient = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!)
    let cacheStore: any CacheStoreContract

    init(root: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)) {
        cacheStore = CodableCacheStore(diskStore: FileDiskStore(root: root))
    }
}
