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

/// The document is generated, which is exactly why it is worth asserting: a
/// property added to an entity changes the selection set silently, and a
/// malformed argument list is a 400 the app only discovers at runtime.
@Suite("LocationsQuery")
struct LocationsQueryTests {

    @Test("the page is an argument of the root field")
    func documentPassesThePage() {
        let document = LocationsQuery(page: 1).document

        #expect(document.contains("locations("))
        #expect(document.contains("page: $page"))
        #expect(document.contains("$page: Int"))
    }

    /// The feature sends no filter at all — there is no search on this screen —
    /// and an empty `filter: {}` is not something to send "just in case": the
    /// builder has to omit the argument entirely or the server rejects the
    /// operation.
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

    /// `created` is the API's own bookkeeping timestamp and nothing on this
    /// screen shows it, so asking for it would be 126 locations' worth of a
    /// string nobody reads. `url` is the REST address of the same record and does
    /// not exist on this schema at all — asking for it would be a 400.
    @Test("neither url nor created is requested")
    func documentLeavesOutTheBookkeepingFields() {
        let document = LocationsQuery(page: 1).document

        #expect(!document.contains("created"))
        #expect(!document.contains("url"))
    }

    /// `@Document` peels the array and the optional off `[LocationResidentEntity]?`
    /// and expands it, which is the whole reason the nested type exists. A bare
    /// `residents` field with no selection set is not valid GraphQL.
    @Test("residents expands into a nested selection set of id and image")
    func documentNestsTheResidentSelection() throws {
        let document = LocationsQuery(page: 1).document
        let selection = try #require(document.range(of: "residents {"))
        let body = document[selection.upperBound...]
        let closing = try #require(body.range(of: "}"))
        let nested = body[..<closing.lowerBound]

        #expect(nested.contains("id"))
        #expect(nested.contains("image"))
        // The resident is a sliver of a character on purpose: pulling the whole
        // eleven-field entity into every location page would be hundreds of
        // residents' worth of fields nothing draws.
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

    /// The root field is part of the key, so a locations page can never be read
    /// back as something else's cached response.
    @Test("the identifier names the root field")
    func identifierNamesTheRootField() {
        #expect(LocationsQuery(page: 1).cacheIdentifier.hasPrefix("locations|"))
    }
}
