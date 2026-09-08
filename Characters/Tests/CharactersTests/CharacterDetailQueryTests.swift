//
//  CharacterDetailQueryTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Testing
@testable import Characters

/// The document is generated from the entity's `@Document`, so what these pin is
/// the thing a generator cannot check: that the entity declares every field the
/// screen draws, and that nothing was added which would drag a second level of
/// the schema down with it.
@Suite("CharacterDetailQuery")
struct CharacterDetailQueryTests {

    @Test("the root field is the single character")
    func rootFieldIsTheCharacter() {
        #expect(CharacterDetailQuery.objectRequested == "character")
        #expect(CharacterDetailQuery(id: "1").document.contains("result: character(id: $id)"))
    }

    /// `ID!` rather than `String!`: the schema's own scalar for an identifier,
    /// and the server rejects the operation outright if the variable is declared
    /// as anything else.
    @Test("the id travels as a declared ID variable, never interpolated")
    func idIsAVariable() {
        let document = CharacterDetailQuery(id: "42").document

        #expect(document.contains("$id: ID!"))
        #expect(!document.contains("\"42\""))
    }

    /// Every field the detail screen shows, and the list of them is the point:
    /// a field dropped from the entity would compile fine and leave a row of the
    /// info card permanently missing.
    @Test("the selection asks for every field the screen draws", arguments: [
        "id", "name", "status", "species", "type", "gender", "image"
    ])
    func selectionIncludesEveryScalar(field: String) {
        #expect(CharacterDetailQuery(id: "1").document.contains(field))
    }

    /// `@Document` peels the optional and the array off the property's type,
    /// which is what produces the nested selection — no hand-written document,
    /// and no chance of asking for a field the entity cannot decode.
    @Test("the nested selections are the ones the entities declare")
    func nestedSelectionsAreGenerated() {
        let document = CharacterDetailQuery(id: "1").document

        #expect(document.contains("origin {"))
        #expect(document.contains("location {"))
        #expect(document.contains("dimension"))
        #expect(document.contains("episode {"))
        #expect(document.contains("air_date"))
    }

    /// The episode selection deliberately stops at the episode's own fields. An
    /// episode carries its own `characters`, and following that edge would fetch
    /// the entire cast of every episode a character appears in — for a list that
    /// shows three lines per row.
    @Test("the episode selection does not follow the edge back to characters")
    func episodesDoNotCarryTheirCast() {
        #expect(!CharacterDetailQuery(id: "1").document.contains("characters"))
    }

    /// The REST address of the same record, of no use to a client that speaks
    /// GraphQL — and it is the one field of the schema this screen leaves out,
    /// so an accidental `url` on the entity would be visible here.
    @Test("url is the one field left out")
    func urlIsNotSelected() {
        #expect(!CharacterDetailQuery(id: "1").document.contains("url"))
    }

    // MARK: - Cache identity

    @Test("two characters address two entries")
    func identifierDiffersPerCharacter() {
        #expect(CharacterDetailQuery(id: "1").cacheIdentifier != CharacterDetailQuery(id: "2").cacheIdentifier)
    }

    @Test("the same character always addresses the same entry")
    func identifierIsStable() {
        #expect(CharacterDetailQuery(id: "1").cacheIdentifier == CharacterDetailQuery(id: "1").cacheIdentifier)
    }

    @Test("the identifier names the root field")
    func identifierNamesTheRootField() {
        #expect(CharacterDetailQuery(id: "1").cacheIdentifier.hasPrefix("character|"))
    }

    /// The detail shares the `characters` namespace with the list's pages, so
    /// the two must not be able to address the same entry — a page read back as
    /// a character, or the reverse, is a decoding failure at best.
    @Test("a detail never collides with a page or with the offers")
    func identifierDiffersFromTheOtherQueries() {
        let detail = CharacterDetailQuery(id: "1").cacheIdentifier

        #expect(detail != CharactersQuery(page: 1).cacheIdentifier)
        #expect(detail != JustWatchShowOffersQuery().cacheIdentifier)
    }
}
