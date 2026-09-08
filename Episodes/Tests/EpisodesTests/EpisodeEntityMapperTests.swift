//
//  EpisodeEntityMapperTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Episodes

/// The mapper is where the feature decides what it cannot draw a row without,
/// so these tests are that decision, field by field: four things are required,
/// two are decoration that can never fail a row.
@Suite("EpisodeEntityMapper")
struct EpisodeEntityMapperTests {

    @Test("a nil entity is an error, not an empty episode")
    func nilEntityThrows() {
        #expect(throws: EpisodeEntityMapperError.self) {
            _ = try EpisodeEntityMapper().map(nil)
        }
    }

    @Test("a complete entity maps every field")
    func completeEntityMaps() throws {
        let episode = try EpisodeEntityMapper().map(.make())

        #expect(episode.id == "1")
        #expect(episode.name == "Pilot")
        #expect(episode.airDate == "December 2, 2013")
        #expect(episode.code == "S01E01")
        #expect(episode.season == 1)
        #expect(episode.number == 1)
        #expect(episode.characters.map(\.id) == ["1", "2"])
    }

    @Test("a missing id fails the episode")
    func missingIdThrows() {
        #expect(throws: EpisodeEntityMapperError.self) {
            _ = try EpisodeEntityMapper().map(.make(id: nil))
        }
    }

    @Test("a missing name fails the episode")
    func missingNameThrows() {
        #expect(throws: EpisodeEntityMapperError.self) {
            _ = try EpisodeEntityMapper().map(.make(name: nil))
        }
    }

    @Test("a missing air date fails the episode")
    func missingAirDateThrows() {
        #expect(throws: EpisodeEntityMapperError.self) {
            _ = try EpisodeEntityMapper().map(.make(airDate: nil))
        }
    }

    @Test("a missing episode code fails the episode")
    func missingCodeThrows() {
        #expect(throws: EpisodeEntityMapperError.self) {
            _ = try EpisodeEntityMapper().map(.make(code: nil))
        }
    }

    /// A code that will not parse has no season to be grouped under, and
    /// inventing one would quietly put a row in a group that does not exist.
    @Test("an unparseable code is rejected rather than guessed at", arguments: [
        "Season 1", "S01", "E01", "S01E", "SxxExx", "1x01", "", " S01E01 "
    ])
    func invalidCodeThrows(code: String) {
        #expect(throws: EpisodeEntityMapperError.self) {
            _ = try EpisodeEntityMapper().map(.make(code: code))
        }
    }

    /// The schema promises a format, not a casing, and a lowercase code
    /// describes exactly the same episode.
    @Test("a lowercase code is accepted", arguments: ["s01e05", "S01e05", "s01E05"])
    func lowercaseCodeIsAccepted(code: String) throws {
        let episode = try EpisodeEntityMapper().map(.make(code: code))

        #expect(episode.season == 1)
        #expect(episode.number == 5)
        // Verbatim: the row shows back what the API said, whatever its casing.
        #expect(episode.code == code)
    }

    @Test("multi-digit seasons and numbers parse")
    func multiDigitCodeParses() throws {
        let episode = try EpisodeEntityMapper().map(.make(code: "S12E103"))

        #expect(episode.season == 12)
        #expect(episode.number == 103)
    }

    // MARK: - created

    @Test("created parses with fractional seconds")
    func createdWithFractionalSecondsParses() throws {
        let episode = try EpisodeEntityMapper().map(.make(created: "2021-10-15T17:00:24.105Z"))

        let expected = ISO8601DateFormatter()
        expected.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(episode.created == expected.date(from: "2021-10-15T17:00:24.105Z"))
    }

    /// `ISO8601DateFormatter` returns `nil` rather than a close-enough date when
    /// the string does not carry exactly the components the options asked for,
    /// so both spellings need their own reading.
    @Test("created parses without fractional seconds")
    func createdWithoutFractionalSecondsParses() throws {
        let episode = try EpisodeEntityMapper().map(.make(created: "2021-10-15T17:00:24Z"))

        let expected = ISO8601DateFormatter()
        expected.formatOptions = [.withInternetDateTime]
        #expect(episode.created == expected.date(from: "2021-10-15T17:00:24Z"))
    }

    @Test("an absent or unparseable created is nil, never fatal",
          arguments: [nil, "", "yesterday", "2021-10-15"] as [String?])
    func createdIsOptional(created: String?) throws {
        let episode = try EpisodeEntityMapper().map(.make(created: created))

        #expect(episode.created == nil)
        // The point of the test: the episode still maps.
        #expect(episode.name == "Pilot")
    }

    // MARK: - characters

    @Test("a character missing its id is skipped, not fatal")
    func characterWithoutIdIsSkipped() throws {
        let entity = EpisodeEntity.make(characters: [
            EpisodeCharacterEntity(id: nil, image: URL(string: "https://example.com/1.jpeg")),
            EpisodeCharacterEntity(id: "2", image: URL(string: "https://example.com/2.jpeg"))
        ])

        #expect(try EpisodeEntityMapper().map(entity).characters.map(\.id) == ["2"])
    }

    @Test("a character missing its image is skipped, not fatal")
    func characterWithoutImageIsSkipped() throws {
        let entity = EpisodeEntity.make(characters: [
            EpisodeCharacterEntity(id: "1", image: nil),
            EpisodeCharacterEntity(id: "2", image: URL(string: "https://example.com/2.jpeg"))
        ])

        #expect(try EpisodeEntityMapper().map(entity).characters.map(\.id) == ["2"])
    }

    @Test("an absent characters array is an empty strip")
    func nilCharactersMapsToEmpty() throws {
        #expect(try EpisodeEntityMapper().map(.make(characters: nil)).characters.isEmpty)
    }

    // MARK: - Errors

    /// The descriptions are what a developer reads in the console when a page
    /// silently loses a row, so they have to name the thing that was wrong.
    @Test("errors describe what was missing")
    func errorsAreDescriptive() {
        #expect(EpisodeEntityMapperError.noEntityError("EpisodeEntity")
            .errorDescription?.contains("EpisodeEntity") == true)
        #expect(EpisodeEntityMapperError.missingProperty("air_date")
            .errorDescription?.contains("air_date") == true)
        #expect(EpisodeEntityMapperError.invalidCode("Season 1")
            .errorDescription?.contains("Season 1") == true)
    }
}
