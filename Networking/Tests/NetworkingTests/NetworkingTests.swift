//
//  NetworkingTests.swift
//  Networking
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation
import Testing
@testable import Networking

/// `cacheIdentifier`: two calls for the same thing must share a file; two that differ must
/// never collide.
@Suite("GraphQLQuery cache identity")
struct GraphQLQueryCacheIdentifierTests {

    @Test("the same query values produce the same identifier")
    func stableForEqualQueries() {
        let first = CharactersTestQuery(page: 1, name: nil)
        let second = CharactersTestQuery(page: 1, name: nil)

        #expect(first.cacheIdentifier == second.cacheIdentifier)
    }

    @Test("a different page is a different identifier")
    func pageIsPartOfIdentity() {
        let first = CharactersTestQuery(page: 1, name: nil)
        let second = CharactersTestQuery(page: 2, name: nil)

        #expect(first.cacheIdentifier != second.cacheIdentifier)
    }

    @Test("a different filter value is a different identifier")
    func filtersArePartOfIdentity() {
        let unfiltered = CharactersTestQuery(page: 1, name: nil)
        let filtered = CharactersTestQuery(page: 1, name: "Rick")

        #expect(unfiltered.cacheIdentifier != filtered.cacheIdentifier)
    }

    @Test("the order the encoder emits variables in does not matter")
    func variableOrderIsIrrelevant() {
        // `variablesJSON` sorts keys, so opposite emission order must still normalize identically.
        let natural = ShuffledVariablesTestQuery(id: "1", name: "Rick", reverseKeyOrder: false)
        let reversed = ShuffledVariablesTestQuery(id: "1", name: "Rick", reverseKeyOrder: true)

        #expect(natural.cacheIdentifier == reversed.cacheIdentifier)
    }

    @Test("changing the entity's selection set changes the identifier")
    func documentIsPartOfIdentity() {
        // Only the selection set differs, as when @Document gains a field — old entries must
        // not decode into the new shape.
        let narrow = CharactersTestQuery(page: 1, name: nil)
        let wide = WideCharactersTestQuery(page: 1, name: nil)

        #expect(narrow.document != wide.document)
        #expect(narrow.cacheIdentifier != wide.cacheIdentifier)
    }

    @Test("a non-paginated query gets an identifier too")
    func worksForNonPaginatedQueries() {
        let rick = CharacterDetailTestQuery(id: "1")
        let morty = CharacterDetailTestQuery(id: "2")

        #expect(rick.cacheIdentifier == CharacterDetailTestQuery(id: "1").cacheIdentifier)
        #expect(rick.cacheIdentifier != morty.cacheIdentifier)
    }

    @Test("two operations on different root fields never collide")
    func rootFieldIsPartOfIdentity() {
        let list = CharactersTestQuery(page: 1, name: nil)
        let detail = CharacterDetailTestQuery(id: "1")

        #expect(list.cacheIdentifier != detail.cacheIdentifier)
    }
}

// MARK: - Test doubles

private struct NarrowEntity: GraphQLDocumentConvertible, Codable, Sendable {
    let id: String?
    let name: String?

    static func document(depth: Int) -> String {
        """
        id
        name
        """
    }
}

/// The same entity after somebody added a field to its `@Document`.
private struct WideEntity: GraphQLDocumentConvertible, Codable, Sendable {
    let id: String?
    let name: String?
    let status: String?

    static func document(depth: Int) -> String {
        """
        id
        name
        status
        """
    }
}

/// Endpoints are asserted rather than trusted to review — a typo sends requests to the wrong host.
@Suite("GraphQLClient endpoints")
struct GraphQLClientEndpointTests {

    @Test("the Rick and Morty client points at rickandmortyapi")
    func rickAndMortyEndpoint() {
        #expect(GraphQLClient.rickAndMorty().endpoint.absoluteString == "https://rickandmortyapi.com/graphql")
    }

    @Test("the JustWatch client points at the JustWatch endpoint")
    func justWatchEndpoint() {
        #expect(GraphQLClient.justWatch().endpoint.absoluteString == "https://apis.justwatch.com/graphql")
    }

    @Test("the two clients are not the same endpoint")
    func endpointsDiffer() {
        #expect(GraphQLClient.rickAndMorty().endpoint != GraphQLClient.justWatch().endpoint)
    }

    // The logger is why JustWatch is built by the app, not the feature — an unlogged request
    // would be invisible in the inspector.
    @Test("the JustWatch client keeps the logger it is given")
    func justWatchKeepsItsLogger() {
        let store = APILogStore()

        let client = GraphQLClient.justWatch(logger: store)

        #expect(client.logger as? APILogStore === store)
    }
}

private struct CharactersTestQuery: GraphQLPaginatedQuery {
    typealias ResponseEntity = NarrowEntity

    static var objectRequested: String { "characters" }

    let page: Int?
    let name: String?
}

private struct WideCharactersTestQuery: GraphQLPaginatedQuery {
    typealias ResponseEntity = WideEntity

    static var objectRequested: String { "characters" }

    let page: Int?
    let name: String?
}

private struct CharacterDetailTestQuery: GraphQLQuery {
    typealias ResponseEntity = NarrowEntity

    static var objectRequested: String { "character" }

    let id: String
}

/// Encodes its two variables in either order, to prove identity depends on values, not order.
private struct ShuffledVariablesTestQuery: GraphQLQuery {
    typealias ResponseEntity = NarrowEntity

    static var objectRequested: String { "character" }

    let id: String
    let name: String
    /// Not encoded — only steers `encode(to:)`; being a stored property, it cancels out of the
    /// cache identity.
    let reverseKeyOrder: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if reverseKeyOrder {
            try container.encode(name, forKey: .name)
            try container.encode(id, forKey: .id)
        } else {
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
        }
    }
}
