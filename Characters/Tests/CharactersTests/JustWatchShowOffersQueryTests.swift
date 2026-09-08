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

/// The one hand-written document in the app, against a server whose schema
/// cannot be introspected — so nothing but these assertions stands between an
/// edit and a `BAD_REQUEST` the app would only discover at runtime, on a
/// third-party endpoint, as a missing button.
///
/// This is the Characters copy of the Episodes suite, mirroring the query it is
/// about: feature packages stay independent, so the pipeline is duplicated and
/// so is its test. The assertions below are what keep the two copies honest —
/// the document text has to stay identical for the two features to address the
/// same cached lookup, and every rule of it is written out here rather than
/// compared against a module this one cannot import.
@Suite("JustWatchShowOffersQuery")
struct JustWatchShowOffersQueryTests {

    // MARK: - The document

    /// The alias is a contract with `GraphQLRootPayload`, which every response in
    /// this app decodes through: spell the root field plainly and the response
    /// decodes into nothing at all.
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

    /// `node(id:)` returns the `Node` interface, so the show's fields are only
    /// reachable through an inline fragment. Without it the server rejects every
    /// field below.
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

    /// The variables are declared once and used everywhere, rather than the
    /// country being interpolated into the document — which would put a value
    /// into the operation text, defeat any server-side caching of it, and make
    /// the cache key change for a reason the hash already covers.
    @Test("the document never interpolates a variable's value")
    func documentInterpolatesNothing() {
        #expect(!JustWatchShowOffersQuery(country: "ES").document.contains("\"ES\""))
        #expect(!JustWatchShowOffersQuery().document.contains("ts20233"))
    }

    // MARK: - Variables

    /// `US` rather than the country the app is used in: it is the territory
    /// whose JustWatch data matches hbomax.com for every episode, where `ES`
    /// carries a wrong UUID for the pilot. See the query's documentation.
    @Test("the query defaults to Rick and Morty in the US catalogue")
    func defaultsAreTheAppsOnlyShow() {
        let query = JustWatchShowOffersQuery()

        #expect(query.id == "ts20233")
        #expect(query.country == "US")
        #expect(query.language == "en")
    }

    /// The stored properties *are* the variables object — the client encodes the
    /// query itself into the request's `variables` — so what goes over the wire
    /// is exactly this, and a property added here becomes a variable whether or
    /// not the document declares one.
    @Test("the variables encode as the three the document declares")
    func variablesEncode() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let json = String(decoding: try encoder.encode(JustWatchShowOffersQuery()), as: UTF8.self)

        #expect(json == #"{"country":"US","id":"ts20233","language":"en"}"#)
    }

    // MARK: - Cache identity

    /// The offers share the `characters` namespace with the list's pages and
    /// every character detail, so none of the three may address the same entry —
    /// a page read back as a show, or the reverse, is a decoding failure at best.
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

    /// Offers are per-territory, so two countries are two different answers to
    /// the same question and must not share one cached entry.
    @Test("two countries are two cache entries")
    func countryIsPartOfTheIdentity() {
        #expect(JustWatchShowOffersQuery(country: "ES").cacheIdentifier
                != JustWatchShowOffersQuery(country: "US").cacheIdentifier)
    }
}
