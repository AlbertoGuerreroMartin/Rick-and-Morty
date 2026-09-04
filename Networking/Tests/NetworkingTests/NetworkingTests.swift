//
//  NetworkingTests.swift
//  Networking
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation
import Testing
@testable import Networking

/// `cacheIdentifier` is the whole basis of the disk cache: two calls that ask
/// the server for the same thing must land on the same file, and two that do not
/// must never collide. Everything below is one of those two statements.
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
        // Same values, encoded with the keys written out in opposite orders.
        // `variablesJSON` sorts keys, so both must normalise to one string.
        let natural = ShuffledVariablesTestQuery(id: "1", name: "Rick", reverseKeyOrder: false)
        let reversed = ShuffledVariablesTestQuery(id: "1", name: "Rick", reverseKeyOrder: true)

        #expect(natural.cacheIdentifier == reversed.cacheIdentifier)
    }

    @Test("changing the entity's selection set changes the identifier")
    func documentIsPartOfIdentity() {
        // Same root field, same variables — only the selection set differs, which
        // is what happens when a property is added to an entity's `@Document`.
        // The old entries must stop being addressed rather than be decoded into
        // the new shape and fail.
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

/// Encodes its two variables in a caller-chosen order, so the test can prove the
/// identifier depends on the values and not on emission order.
private struct ShuffledVariablesTestQuery: GraphQLQuery {
    typealias ResponseEntity = NarrowEntity

    static var objectRequested: String { "character" }

    let id: String
    let name: String
    /// Never encoded; it only steers `encode(to:)`. It is still a stored
    /// property, so it appears identically in both documents and cancels out.
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
