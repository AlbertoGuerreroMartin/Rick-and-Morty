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

@Suite("EpisodesQuery")
struct EpisodesQueryTests {

    @Test("the page is an argument of the root field")
    func documentPassesThePage() {
        let document = EpisodesQuery(page: 1).document

        #expect(document.contains("page: $page"))
        #expect(document.contains("$page: Int"))
    }

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

    @Test("characters expands into a nested selection set of id, name and image")
    func documentNestsTheCharacterSelection() throws {
        let document = EpisodesQuery(page: 1).document
        let selection = try #require(document.range(of: "characters {"))
        let body = document[selection.upperBound...]
        let closing = try #require(body.range(of: "}"))

        #expect(body[..<closing.lowerBound].contains("id"))
        #expect(body[..<closing.lowerBound].contains("name"))
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

    @Test("the identifier names the root field")
    func identifierNamesTheRootField() {
        #expect(EpisodesQuery(page: 1).cacheIdentifier.hasPrefix("episodes|"))
    }
}
