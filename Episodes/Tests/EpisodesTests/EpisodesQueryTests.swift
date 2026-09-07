//
//  EpisodesQueryTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Testing
@testable import Episodes

/// The document is generated, which is exactly why it is worth asserting: a
/// property added to an entity changes the selection set silently, and a
/// malformed argument list is a 400 the app only discovers at runtime.
@Suite("EpisodesQuery")
struct EpisodesQueryTests {

    @Test("the page is an argument of the root field")
    func documentPassesThePage() {
        let document = EpisodesQuery(page: 1).document

        #expect(document.contains("page: $page"))
        #expect(document.contains("$page: Int"))
    }

    /// The feature sends no filter at all — the search is local — and an empty
    /// `filter: {}` is not something to send "just in case": the builder has to
    /// omit the argument entirely or the server rejects the operation.
    @Test("no filter argument is sent")
    func documentHasNoFilter() {
        #expect(!EpisodesQuery(page: 1).document.contains("filter"))
    }

    @Test("the selection set asks for the fields the mapper requires")
    func documentSelectsTheRequiredFields() {
        let document = EpisodesQuery(page: 1).document

        #expect(document.contains("id"))
        #expect(document.contains("name"))
        #expect(document.contains("air_date"))
        #expect(document.contains("episode"))
        #expect(document.contains("created"))
    }

    /// `@Document` peels the array and the optional off `[EpisodeCharacterEntity]?`
    /// and expands it, which is the whole reason the nested type exists. A bare
    /// `characters` field with no selection set is not valid GraphQL.
    @Test("characters expands into a nested selection set of id and image")
    func documentNestsTheCharacterSelection() throws {
        let document = EpisodesQuery(page: 1).document
        let selection = try #require(document.range(of: "characters {"))
        let body = document[selection.upperBound...]
        let closing = try #require(body.range(of: "}"))

        #expect(body[..<closing.lowerBound].contains("id"))
        #expect(body[..<closing.lowerBound].contains("image"))
    }

    @Test("the page info the walk needs is selected")
    func documentSelectsThePageInfo() {
        let document = EpisodesQuery(page: 1).document

        #expect(document.contains("info {"))
        #expect(document.contains("next"))
        #expect(document.contains("pages"))
    }

    // MARK: - Cache identity

    @Test("two pages address two cache entries")
    func pagesGetDifferentIdentifiers() {
        #expect(EpisodesQuery(page: 1).cacheIdentifier != EpisodesQuery(page: 2).cacheIdentifier)
    }

    @Test("the same page always addresses the same entry")
    func theSamePageIsStable() {
        #expect(EpisodesQuery(page: 3).cacheIdentifier == EpisodesQuery(page: 3).cacheIdentifier)
    }

    /// The root field is part of the key, so an episodes page can never be read
    /// back as something else's cached response.
    @Test("the identifier names the root field")
    func identifierNamesTheRootField() {
        #expect(EpisodesQuery(page: 1).cacheIdentifier.hasPrefix("episodes|"))
    }
}
