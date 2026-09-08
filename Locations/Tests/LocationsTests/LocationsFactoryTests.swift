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
        #expect(graph.viewModel.paginationPublished == .end)
    }

    @Test("both section mappers read the same view model")
    func bothMappersShareTheViewModel() {
        let graph = LocationsFactory.makeGraph(dependencies: StubLocationsDependencies())

        #expect(graph.carouselMapper.viewModel as AnyObject === graph.viewModel)
        #expect(graph.detailMapper.viewModel as AnyObject === graph.viewModel)
    }

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

/// Stands in for the app container; nothing here reaches the network.
struct StubLocationsDependencies: LocationsDependencies {
    let graphQLClient = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!)
    let cacheStore: any CacheStoreContract

    init(root: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)) {
        cacheStore = CodableCacheStore(diskStore: FileDiskStore(root: root))
    }
}
