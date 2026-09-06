//
//  GraphQLDocumentLayoutTests.swift
//  Networking
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation
import Testing
@testable import Networking

/// The layout is for people, not the server — GraphQL ignores whitespace — but
/// it is what the API log prints, so it is pinned here exactly.
@Suite("GraphQL document layout")
struct GraphQLDocumentLayoutTests {

    @Test("a nested field puts its selection on indented lines of its own")
    func nestedFieldIsIndented() {
        #expect(GraphQLField.resolve("origin", Place.self, depth: 2) == """
        origin {
          name
          dimension
        }
        """)
    }

    @Test("indentation compounds through every level of nesting")
    func nestingCompounds() {
        #expect(Character.document(depth: 3) == """
        id
        origin {
          name
          dimension
        }
        episodes {
          title
          character {
            id
          }
        }
        """)
    }

    @Test("a paginated query lays out the whole operation one field per line")
    func paginatedOperationLayout() {
        #expect(CharactersQuery(page: 1, name: "Rick").document == """
        query($page: Int, $name: String) {
          result: characters(page: $page, filter: { name: $name }) {
            info {
              count
              pages
              next
            }
            results {
              id
              origin {
                name
                dimension
              }
              episodes {
                title
                character {
                  id
                }
              }
            }
          }
        }
        """)
    }
}

// MARK: - Test doubles

/// Hand-written `document(depth:)` in the shape the `@Document` macro expands
/// to, so the layout is tested without depending on the macro plugin, which
/// only builds for the host.
private struct Place: GraphQLDocumentConvertible, Decodable {
    let name: String?
    let dimension: String?

    static func document(depth: Int) -> String {
        ([GraphQLField.resolve("name", String.self, depth: depth),
          GraphQLField.resolve("dimension", String.self, depth: depth)] as [String?])
            .compactMap(\.self).joined(separator: "\n")
    }
}

private struct Episode: GraphQLDocumentConvertible, Decodable {
    let title: String?
    let character: Character?

    static func document(depth: Int) -> String {
        ([GraphQLField.resolve("title", String.self, depth: depth),
          GraphQLField.resolve("character", Character.self, depth: depth)] as [String?])
            .compactMap(\.self).joined(separator: "\n")
    }
}

private struct Character: GraphQLDocumentConvertible, Decodable {
    let id: String?
    let origin: Place?
    let episodes: [Episode]?

    static func document(depth: Int) -> String {
        ([GraphQLField.resolve("id", String.self, depth: depth),
          GraphQLField.resolve("origin", Place.self, depth: depth),
          GraphQLField.resolve("episodes", Episode.self, depth: depth)] as [String?])
            .compactMap(\.self).joined(separator: "\n")
    }
}

private struct CharactersQuery: GraphQLPaginatedQuery {
    typealias ResponseEntity = Character

    static var objectRequested: String { "characters" }

    let page: Int?
    let name: String?
}
