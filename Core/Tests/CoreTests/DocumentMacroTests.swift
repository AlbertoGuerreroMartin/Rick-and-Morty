//
//  DocumentMacroTests.swift
//  Core
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Macros

private let macros: [String: MacroSpec] = ["Document": MacroSpec(type: DocumentMacro.self)]

/// Bridges swift-syntax's assertion onto Swift Testing, so a mismatch shows as an `Issue`.
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

// swiftlint:disable line_length
/// Optionals and arrays are peeled off so the check sees the element type.
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
// swiftlint:enable line_length

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

/// `as [String?]` keeps this compiling: a bare `[]` literal has no element type to infer.
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
