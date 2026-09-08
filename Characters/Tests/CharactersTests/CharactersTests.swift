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

@Suite("Characters factories")
@MainActor
struct CharactersFactoryTests {

    @Test("the characters factory builds a graph in its initial state")
    func charactersFactoryBuildsTheGraph() {
        let navigator = CharactersNavigator()
        let graph = CharactersFactory.makeGraph(dependencies: StubCharactersDependencies(),
                                                navigator: navigator)

        // Passed through, not built here: the graph must hand the screen the object a deep link writes to.
        #expect(graph.navigator === navigator)
        #expect(graph.navigator.path.isEmpty)
        #expect(graph.viewModel.charactersPublished == nil)
        #expect(graph.viewModel.loadingPublished == false)
        #expect(graph.viewModel.filterPublished == .empty)
    }

    /// A graph that dropped the id would fetch whichever character the server answered for an empty query.
    @Test("the detail factory builds a graph for the route's character")
    func detailFactoryBuildsTheGraph() {
        let graph = CharacterDetailFactory.makeGraph(dependencies: StubCharactersDependencies(), id: "42")

        #expect(graph.viewModel.id == "42")
        #expect(graph.viewModel.detailPublished == nil)
        #expect(graph.viewModel.loadingPublished == false)
        #expect(graph.viewModel.loadFailedPublished == false)
    }
}

/// Stands in for the app container; nothing here reaches the network.
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
