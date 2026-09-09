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

@Suite("CharacterDetailQuery")
struct CharacterDetailQueryTests {

    @Test("the root field is the single character")
    func rootFieldIsTheCharacter() {
        #expect(CharacterDetailQuery.objectRequested == "character")
        #expect(CharacterDetailQuery(id: "1").document.contains("result: character(id: $id)"))
    }

    @Test("the id travels as a declared ID variable, never interpolated")
    func idIsAVariable() {
        let document = CharacterDetailQuery(id: "42").document

        #expect(document.contains("$id: ID!"))
        #expect(!document.contains("\"42\""))
    }

    @Test("the selection asks for every field the screen draws", arguments: [
        "id", "name", "status", "species", "type", "gender", "image"
    ])
    func selectionIncludesEveryScalar(field: String) {
        #expect(CharacterDetailQuery(id: "1").document.contains(field))
    }

    /// Nested selections come from `@Document` peeling the optional/array off the property type.
    @Test("the nested selections are the ones the entities declare")
    func nestedSelectionsAreGenerated() {
        let document = CharacterDetailQuery(id: "1").document

        #expect(document.contains("origin {"))
        #expect(document.contains("location {"))
        #expect(document.contains("dimension"))
        #expect(document.contains("episode {"))
        #expect(document.contains("air_date"))
    }

    /// Following the episode's own `characters` edge would fetch the entire cast of every episode.
    @Test("the episode selection does not follow the edge back to characters")
    func episodesDoNotCarryTheirCast() {
        #expect(!CharacterDetailQuery(id: "1").document.contains("characters"))
    }

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

    /// Shares the `characters` cache namespace with pages and offers.
    @Test("a detail never collides with a page or with the offers")
    func identifierDiffersFromTheOtherQueries() {
        let detail = CharacterDetailQuery(id: "1").cacheIdentifier

        #expect(detail != CharactersQuery(page: 1).cacheIdentifier)
        #expect(detail != JustWatchShowOffersQuery().cacheIdentifier)
    }
}
