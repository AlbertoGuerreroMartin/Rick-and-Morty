//
//  JustWatchShowOffersQueryTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Testing
@testable import Characters

@Suite("JustWatchShowOffersQuery")
struct JustWatchShowOffersQueryTests {

    // MARK: - The document

    @Test("the root field is aliased to result")
    func documentAliasesTheRootField() {
        #expect(JustWatchShowOffersQuery().document.contains("result: node(id: $id)"))
    }

    @Test("all three variables are declared with the server's own types")
    func documentDeclaresItsVariables() {
        let document = JustWatchShowOffersQuery().document

        #expect(document.contains("$id: ID!"))
        #expect(document.contains("$country: Country!"))
        #expect(document.contains("$language: Language!"))
    }

    @Test("the show's fields are reached through an inline fragment")
    func documentUsesAnInlineFragment() {
        #expect(JustWatchShowOffersQuery().document.contains("... on Show {"))
    }

    @Test("the selection set is the entity's own")
    func documentSelectsTheEntity() {
        let document = JustWatchShowOffersQuery().document

        #expect(document.contains("offers(country: $country, platform: WEB)"))
        #expect(document.contains("deeplinkURL(platform: IOS)"))
        #expect(document.contains("technicalName"))
    }

    @Test("the document never interpolates a variable's value")
    func documentInterpolatesNothing() {
        #expect(!JustWatchShowOffersQuery(country: "ES").document.contains("\"ES\""))
        #expect(!JustWatchShowOffersQuery().document.contains("ts20233"))
    }

    // MARK: - Variables

    /// `US`, not the app's own locale: `ES` carries a wrong UUID for the pilot.
    @Test("the query defaults to Rick and Morty in the US catalogue")
    func defaultsAreTheAppsOnlyShow() {
        let query = JustWatchShowOffersQuery()

        #expect(query.id == "ts20233")
        #expect(query.country == "US")
        #expect(query.language == "en")
    }

    @Test("the variables encode as the three the document declares")
    func variablesEncode() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let json = String(decoding: try encoder.encode(JustWatchShowOffersQuery()), as: UTF8.self)

        #expect(json == #"{"country":"US","id":"ts20233","language":"en"}"#)
    }

    // MARK: - Cache identity

    @Test("the offers never collide with a page or a detail")
    func identifierDiffersFromTheOtherQueries() {
        let offers = JustWatchShowOffersQuery().cacheIdentifier

        #expect(offers != CharactersQuery(page: 1).cacheIdentifier)
        #expect(offers != CharacterDetailQuery(id: "1").cacheIdentifier)
    }

    @Test("the identifier names the root field")
    func identifierNamesTheRootField() {
        #expect(JustWatchShowOffersQuery().cacheIdentifier.hasPrefix("node|"))
    }

    @Test("the same lookup always addresses the same entry")
    func identifierIsStable() {
        #expect(JustWatchShowOffersQuery().cacheIdentifier == JustWatchShowOffersQuery().cacheIdentifier)
    }

    @Test("two countries are two cache entries")
    func countryIsPartOfTheIdentity() {
        #expect(JustWatchShowOffersQuery(country: "ES").cacheIdentifier
                != JustWatchShowOffersQuery(country: "US").cacheIdentifier)
    }
}
