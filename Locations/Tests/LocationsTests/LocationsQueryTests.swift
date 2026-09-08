//
//  LocationsQueryTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation
import Networking
import Testing
@testable import Locations

@Suite("LocationsQuery")
struct LocationsQueryTests {

    @Test("the page is an argument of the root field")
    func documentPassesThePage() {
        let document = LocationsQuery(page: 1).document

        #expect(document.contains("locations("))
        #expect(document.contains("page: $page"))
        #expect(document.contains("$page: Int"))
    }

    @Test("no filter argument is sent")
    func documentHasNoFilter() {
        #expect(!LocationsQuery(page: 1).document.contains("filter"))
    }

    @Test("the selection set asks for every field the mapper reads")
    func documentSelectsTheRequiredFields() {
        let document = LocationsQuery(page: 1).document

        #expect(document.contains("id"))
        #expect(document.contains("name"))
        #expect(document.contains("type"))
        #expect(document.contains("dimension"))
    }

    /// `url` doesn't exist on this schema; requesting it would be a 400.
    @Test("neither url nor created is requested")
    func documentLeavesOutTheBookkeepingFields() {
        let document = LocationsQuery(page: 1).document

        #expect(!document.contains("created"))
        #expect(!document.contains("url"))
    }

    @Test("residents expands into a nested selection set of id and image")
    func documentNestsTheResidentSelection() throws {
        let document = LocationsQuery(page: 1).document
        let selection = try #require(document.range(of: "residents {"))
        let body = document[selection.upperBound...]
        let closing = try #require(body.range(of: "}"))
        let nested = body[..<closing.lowerBound]

        #expect(nested.contains("id"))
        #expect(nested.contains("image"))
        #expect(!nested.contains("status"))
        #expect(!nested.contains("species"))
    }

    @Test("the page info the pagination state needs is selected")
    func documentSelectsThePageInfo() {
        let document = LocationsQuery(page: 1).document

        #expect(document.contains("info {"))
        #expect(document.contains("next"))
    }

    // MARK: - Cache identity

    @Test("two pages address two cache entries")
    func pagesGetDifferentIdentifiers() {
        #expect(LocationsQuery(page: 1).cacheIdentifier != LocationsQuery(page: 2).cacheIdentifier)
    }

    @Test("the same page always addresses the same entry")
    func theSamePageIsStable() {
        #expect(LocationsQuery(page: 3).cacheIdentifier == LocationsQuery(page: 3).cacheIdentifier)
    }

    @Test("the identifier names the root field")
    func identifierNamesTheRootField() {
        #expect(LocationsQuery(page: 1).cacheIdentifier.hasPrefix("locations|"))
    }
}
