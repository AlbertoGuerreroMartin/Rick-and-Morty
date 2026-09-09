//
//  EpisodeEntityMapperTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Episodes

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

    @Test("an unparseable code is rejected rather than guessed at", arguments: [
        "Season 1", "S01", "E01", "S01E", "SxxExx", "1x01", "", " S01E01 "
    ])
    func invalidCodeThrows(code: String) {
        #expect(throws: EpisodeEntityMapperError.self) {
            _ = try EpisodeEntityMapper().map(.make(code: code))
        }
    }

    @Test("a lowercase code is accepted", arguments: ["s01e05", "S01e05", "s01E05"])
    func lowercaseCodeIsAccepted(code: String) throws {
        let episode = try EpisodeEntityMapper().map(.make(code: code))

        #expect(episode.season == 1)
        #expect(episode.number == 5)
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
        #expect(episode.name == "Pilot")
    }

    // MARK: - characters

    @Test("a character missing its id is skipped, not fatal")
    func characterWithoutIdIsSkipped() throws {
        let entity = EpisodeEntity.make(characters: [
            EpisodeCharacterEntity(id: nil, name: "Rick Sanchez", image: URL(string: "https://example.com/1.jpeg")),
            EpisodeCharacterEntity(id: "2", name: "Morty Smith", image: URL(string: "https://example.com/2.jpeg"))
        ])

        #expect(try EpisodeEntityMapper().map(entity).characters.map(\.id) == ["2"])
    }

    @Test("a character missing its image is skipped, not fatal")
    func characterWithoutImageIsSkipped() throws {
        let entity = EpisodeEntity.make(characters: [
            EpisodeCharacterEntity(id: "1", name: "Rick Sanchez", image: nil),
            EpisodeCharacterEntity(id: "2", name: "Morty Smith", image: URL(string: "https://example.com/2.jpeg"))
        ])

        #expect(try EpisodeEntityMapper().map(entity).characters.map(\.id) == ["2"])
    }

    @Test("a character's name is carried through, and its absence is not fatal")
    func characterNamesAreCarriedThrough() throws {
        let entity = EpisodeEntity.make(characters: [
            EpisodeCharacterEntity(id: "1", name: "Rick Sanchez",
                                   image: URL(string: "https://example.com/1.jpeg")),
            EpisodeCharacterEntity(id: "2", name: nil,
                                   image: URL(string: "https://example.com/2.jpeg"))
        ])

        let characters = try EpisodeEntityMapper().map(entity).characters

        #expect(characters.map(\.id) == ["1", "2"])
        #expect(characters.map(\.name) == ["Rick Sanchez", nil])
    }

    @Test("an absent characters array is an empty strip")
    func nilCharactersMapsToEmpty() throws {
        #expect(try EpisodeEntityMapper().map(.make(characters: nil)).characters.isEmpty)
    }

    // MARK: - Errors

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
