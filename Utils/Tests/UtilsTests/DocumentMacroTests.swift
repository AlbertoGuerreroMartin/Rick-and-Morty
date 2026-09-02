//
//  DocumentMacroTests.swift
//  Utils
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import UtilsMacros

private let macros: [String: MacroSpec] = ["Document": MacroSpec(type: DocumentMacro.self)]

/// Bridges swift-syntax's framework-agnostic assertion onto Swift Testing, so a
/// mismatch shows up as a normal `Issue` instead of an XCTest failure.
private func expand(
    _ original: String,
    into expected: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    assertMacroExpansion(
        original,
        expandedSource: expected,
        macroSpecs: macros,
        failureHandler: { failure in
            Issue.record(Comment(rawValue: failure.message), sourceLocation: sourceLocation)
        }
    )
}

@Test func resolvesEveryStoredPropertyThroughItsType() {
    expand(
        """
        @Document
        struct CharacterEntity {
            let id: String
            let image: URL?
        }
        """,
        into: """
        struct CharacterEntity {
            let id: String
            let image: URL?

            static func document(depth: Int) -> String {
                ([GraphQLField.resolve("id", String.self, depth: depth), GraphQLField.resolve("image", URL.self, depth: depth)] as [String?]).compactMap(\\.self).joined(separator: "\\n")
            }
        }
        """
    )
}

/// Optionals and arrays are peeled off so the runtime check sees the element
/// type — `[Episode]?` has to resolve against `Episode`, not against the array.
@Test func peelsOptionalsAndArraysDownToTheBaseType() {
    expand(
        """
        @Document
        struct Entity {
            let origin: Place?
            let episodes: [Episode]
            let tags: [String]?
            let owner: Place!
        }
        """,
        into: """
        struct Entity {
            let origin: Place?
            let episodes: [Episode]
            let tags: [String]?
            let owner: Place!

            static func document(depth: Int) -> String {
                ([GraphQLField.resolve("origin", Place.self, depth: depth), GraphQLField.resolve("episodes", Episode.self, depth: depth), GraphQLField.resolve("tags", String.self, depth: depth), GraphQLField.resolve("owner", Place.self, depth: depth)] as [String?]).compactMap(\\.self).joined(separator: "\\n")
            }
        }
        """
    )
}

@Test func skipsStaticComputedAndUntypedProperties() {
    expand(
        """
        @Document
        struct Entity {
            let id: String
            static let endpoint = "characters"
            var slug: String {
                id.lowercased()
            }
            let inferred = 42
        }
        """,
        into: """
        struct Entity {
            let id: String
            static let endpoint = "characters"
            var slug: String {
                id.lowercased()
            }
            let inferred = 42

            static func document(depth: Int) -> String {
                ([GraphQLField.resolve("id", String.self, depth: depth)] as [String?]).compactMap(\\.self).joined(separator: "\\n")
            }
        }
        """
    )
}

/// The `as [String?]` annotation is what keeps this case compiling: a bare `[]`
/// literal has no element type to infer.
@Test func emitsAValidEmptyDocumentForATypeWithoutStoredProperties() {
    expand(
        """
        @Document
        struct Empty {
        }
        """,
        into: """
        struct Empty {

            static func document(depth: Int) -> String {
                ([] as [String?]).compactMap(\\.self).joined(separator: "\\n")
            }
        }
        """
    )
}
