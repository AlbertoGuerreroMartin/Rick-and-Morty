//
//  CharactersTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Storage
import Testing
@testable import Characters

/// The factories are the feature's composition roots, and every layer they wire
/// is constructor-injected — so building the real graphs needs nothing but two
/// clients and a cache store, and a missing edge is a compile error here rather
/// than an empty screen at runtime.
///
/// This file used to stand up a `CharactersView` that no longer exists, which
/// meant the whole test target had stopped compiling. What replaced it is the
/// smallest thing worth keeping: that both screens can actually be assembled.
@Suite("Characters factories")
@MainActor
struct CharactersFactoryTests {

    @Test("the characters factory builds a graph in its initial state")
    func charactersFactoryBuildsTheGraph() {
        let graph = CharactersFactory.makeGraph(dependencies: StubCharactersDependencies())

        #expect(graph.viewModel.charactersPublished == nil)
        #expect(graph.viewModel.loadingPublished == false)
        #expect(graph.viewModel.filterPublished == .empty)
    }

    /// The detail's graph is built per pushed screen and carries the id it was
    /// pushed with — a graph that dropped it would fetch whichever character the
    /// server answered for an empty query.
    @Test("the detail factory builds a graph for the route's character")
    func detailFactoryBuildsTheGraph() {
        let graph = CharacterDetailFactory.makeGraph(dependencies: StubCharactersDependencies(), id: "42")

        #expect(graph.viewModel.id == "42")
        #expect(graph.viewModel.detailPublished == nil)
        #expect(graph.viewModel.loadingPublished == false)
        #expect(graph.viewModel.loadFailedPublished == false)
    }
}

/// Stands in for the app container. Nothing here reaches the network, so
/// endpoints that resolve to nothing are exactly right — the point is that the
/// factories can be handed the three things they declare and nothing else.
struct StubCharactersDependencies: CharactersDependencies {
    let graphQLClient = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!)
    let justWatchClient = GraphQLClient(endpoint: URL(string: "https://example.com/justwatch")!)
    let cacheStore: any CacheStoreContract = CodableCacheStore(
        diskStore: FileDiskStore(
            root: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
    )
}
