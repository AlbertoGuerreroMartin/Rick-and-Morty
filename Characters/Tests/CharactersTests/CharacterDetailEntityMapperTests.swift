//
//  CharacterDetailEntityMapperTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Characters

/// The mapper is where the screen decides what it cannot be drawn without, so
/// these tests are that decision, field by field: six things are required, four
/// are optional for four different reasons, and the filmography is the one place
/// a failure costs a row rather than the screen.
@Suite("CharacterDetailEntityMapper")
struct CharacterDetailEntityMapperTests {

    @Test("a nil entity is an error, not an empty character")
    func nilEntityThrows() {
        #expect(throws: CharacterDetailEntityMapperError.self) {
            _ = try CharacterDetailEntityMapper().map(nil)
        }
    }

    @Test("a complete entity maps every field")
    func completeEntityMaps() throws {
        let detail = try CharacterDetailEntityMapper().map(.make(type: "Parasite"))

        #expect(detail.id == "1")
        #expect(detail.name == "Rick Sanchez")
        #expect(detail.status == .alive)
        #expect(detail.species == "Human")
        #expect(detail.type == "Parasite")
        #expect(detail.gender == .male)
        #expect(detail.image.absoluteString == "https://example.com/1.jpeg")
        #expect(detail.origin?.name == "Earth (C-137)")
        #expect(detail.origin?.type == "Planet")
        #expect(detail.origin?.dimension == "Dimension C-137")
        #expect(detail.location?.name == "Citadel of Ricks")
        #expect(detail.episodes.map(\.code) == ["S01E01", "S01E02"])
    }

    // MARK: - The required fields

    @Test("a missing id fails the character")
    func missingIdThrows() {
        #expect(throws: CharacterDetailEntityMapperError.self) {
            _ = try CharacterDetailEntityMapper().map(.make(id: nil))
        }
    }

    @Test("a missing name fails the character")
    func missingNameThrows() {
        #expect(throws: CharacterDetailEntityMapperError.self) {
            _ = try CharacterDetailEntityMapper().map(.make(name: nil))
        }
    }

    @Test("a missing status fails the character")
    func missingStatusThrows() {
        #expect(throws: CharacterDetailEntityMapperError.self) {
            _ = try CharacterDetailEntityMapper().map(.make(status: nil))
        }
    }

    @Test("a missing species fails the character")
    func missingSpeciesThrows() {
        #expect(throws: CharacterDetailEntityMapperError.self) {
            _ = try CharacterDetailEntityMapper().map(.make(species: nil))
        }
    }

    @Test("a missing gender fails the character")
    func missingGenderThrows() {
        #expect(throws: CharacterDetailEntityMapperError.self) {
            _ = try CharacterDetailEntityMapper().map(.make(gender: nil))
        }
    }

    /// The picture is the whole top half of this screen, so a character without
    /// one has nothing to draw rather than a gap to draw around.
    @Test("a missing image fails the character")
    func missingImageThrows() {
        #expect(throws: CharacterDetailEntityMapperError.self) {
            _ = try CharacterDetailEntityMapper().map(.make(image: nil))
        }
    }

    /// The API sends some of these upper camel cased and some lowercased, and it
    /// may grow a value this app has never heard of — so neither enum rejects a
    /// spelling, and a *present* status or gender can never fail the screen.
    @Test("status and gender are read leniently", arguments: [
        ("Alive", "Male"), ("alive", "male"), ("ALIVE", "MALE")
    ])
    func statusAndGenderAreLenient(status: String, gender: String) throws {
        let detail = try CharacterDetailEntityMapper().map(.make(status: status, gender: gender))

        #expect(detail.status == .alive)
        #expect(detail.gender == .male)
    }

    @Test("an unrecognised status or gender falls back to unknown rather than failing")
    func unknownStatusAndGenderFallBack() throws {
        let detail = try CharacterDetailEntityMapper().map(.make(status: "Cronenberged", gender: "Squanchy"))

        #expect(detail.status == .unknown)
        #expect(detail.gender == .unknown)
    }

    // MARK: - type

    /// The API sends `""` rather than `null` for a character with no subtype,
    /// and an empty string would draw a labelled row with nothing after it.
    @Test("a blank type becomes nil", arguments: ["", " ", "   \n "])
    func blankTypeIsNil(type: String) throws {
        #expect(try CharacterDetailEntityMapper().map(.make(type: type)).type == nil)
    }

    @Test("an absent type is nil")
    func absentTypeIsNil() throws {
        #expect(try CharacterDetailEntityMapper().map(.make(type: nil)).type == nil)
    }

    @Test("a type that says something is kept, trimmed")
    func presentTypeIsKept() throws {
        #expect(try CharacterDetailEntityMapper().map(.make(type: "  Parasite  ")).type == "Parasite")
    }

    // MARK: - Places

    @Test("an absent place is nil")
    func absentPlaceIsNil() throws {
        let detail = try CharacterDetailEntityMapper().map(.make(origin: nil, location: nil))

        #expect(detail.origin == nil)
        #expect(detail.location == nil)
    }

    /// A place with no name is no place at all: the name is the only part of it
    /// the screen shows on its own, and a row reading "· Planet" would be worse
    /// than one line fewer.
    @Test("a place with no name is nil")
    func namelessPlaceIsNil() throws {
        let place = CharacterDetailPlace(id: "1", name: nil, type: "Planet", dimension: "C-137")

        #expect(try CharacterDetailEntityMapper().map(.make(origin: place)).origin == nil)
    }

    /// The API's own word for "we do not know", and it is a *name*: rewriting it
    /// into `nil` would throw away the difference between "the API says unknown"
    /// and "the API has no record", and only the first is worth showing.
    @Test("the API's literal unknown is kept verbatim")
    func unknownPlaceNameIsKept() throws {
        let place = CharacterDetailPlace(id: nil, name: "unknown", type: nil, dimension: nil)

        let origin = try CharacterDetailEntityMapper().map(.make(origin: place)).origin

        #expect(origin?.name == "unknown")
        #expect(origin?.type == nil)
        #expect(origin?.dimension == nil)
    }

    @Test("a place's blank type and dimension become nil")
    func blankPlaceFieldsAreNil() throws {
        let place = CharacterDetailPlace(id: "1", name: "Earth", type: "", dimension: "  ")

        let origin = try CharacterDetailEntityMapper().map(.make(origin: place)).origin

        #expect(origin?.name == "Earth")
        #expect(origin?.type == nil)
        #expect(origin?.dimension == nil)
    }

    // MARK: - Episodes

    @Test("no episodes at all is an empty list, not a failure")
    func absentEpisodesAreEmpty() throws {
        #expect(try CharacterDetailEntityMapper().map(.make(episodes: nil)).episodes.isEmpty)
        #expect(try CharacterDetailEntityMapper().map(.make(episodes: [])).episodes.isEmpty)
    }

    @Test("an episode maps its four fields and its parsed numbering")
    func episodeMapsEveryField() throws {
        let entity = CharacterDetailEntity.make(episodes: [
            CharacterDetailEpisode(id: "7", name: "Raising Gazorpazorp",
                                   air_date: "March 10, 2014", episode: "S01E07")
        ])

        let episode = try #require(try CharacterDetailEntityMapper().map(entity).episodes.first)

        #expect(episode.id == "7")
        #expect(episode.name == "Raising Gazorpazorp")
        #expect(episode.airDate == "March 10, 2014")
        #expect(episode.code == "S01E07")
        #expect(episode.season == 1)
        #expect(episode.number == 7)
        // The link comes from a different server and is joined on later.
        #expect(episode.hboMaxURL == nil)
    }

    /// The schema promises a format, not a casing, and a lowercase code
    /// describes exactly the same episode.
    @Test("a lowercase code is accepted", arguments: ["s01e05", "S01e05", "s01E05"])
    func lowercaseCodeIsAccepted(code: String) throws {
        let entity = CharacterDetailEntity.make(episodes: [
            CharacterDetailEpisode(id: "5", name: "Meeseeks and Destroy",
                                   air_date: "January 20, 2014", episode: code)
        ])

        let episode = try #require(try CharacterDetailEntityMapper().map(entity).episodes.first)

        #expect(episode.season == 1)
        #expect(episode.number == 5)
        // Verbatim: the row shows back what the API said, whatever its casing.
        #expect(episode.code == code)
    }

    @Test("multi-digit seasons and numbers parse")
    func multiDigitCodeParses() throws {
        let entity = CharacterDetailEntity.make(episodes: [
            CharacterDetailEpisode(id: "1", name: "Later", air_date: "2026", episode: "S12E103")
        ])

        let episode = try #require(try CharacterDetailEntityMapper().map(entity).episodes.first)

        #expect(episode.season == 12)
        #expect(episode.number == 103)
    }

    /// A code that will not parse cannot be keyed to an HBO Max offer, and
    /// guessing at one would put a play button on the wrong episode — which the
    /// user cannot tell is wrong until they are watching it.
    @Test("an episode with an unparseable code is skipped, not guessed at", arguments: [
        "Season 1", "S01", "E01", "S01E", "SxxExx", "1x01", "", " S01E01 "
    ])
    func invalidCodeSkipsTheEpisode(code: String) throws {
        let entity = CharacterDetailEntity.make(episodes: [
            CharacterDetailEpisode(id: "1", name: "Pilot", air_date: "December 2, 2013", episode: code)
        ])

        #expect(try CharacterDetailEntityMapper().map(entity).episodes.isEmpty)
    }

    @Test("an episode missing a required field is skipped", arguments: [
        CharacterDetailEpisode(id: nil, name: "Pilot", air_date: "December 2, 2013", episode: "S01E01"),
        CharacterDetailEpisode(id: "1", name: nil, air_date: "December 2, 2013", episode: "S01E01"),
        CharacterDetailEpisode(id: "1", name: "Pilot", air_date: nil, episode: "S01E01"),
        CharacterDetailEpisode(id: "1", name: "Pilot", air_date: "December 2, 2013", episode: nil)
    ])
    func incompleteEpisodesAreSkipped(episode: CharacterDetailEpisode) throws {
        #expect(try CharacterDetailEntityMapper().map(.make(episodes: [episode])).episodes.isEmpty)
    }

    /// The asymmetry that makes the whole screen survivable: a bad episode is
    /// one row, and the character it belongs to still loads.
    @Test("a bad episode costs its own row and nothing else")
    func aBadEpisodeDoesNotFailTheCharacter() throws {
        let entity = CharacterDetailEntity.make(episodes: [
            CharacterDetailEpisode(id: "1", name: "Pilot", air_date: "December 2, 2013", episode: "S01E01"),
            CharacterDetailEpisode(id: "2", name: "Broken", air_date: nil, episode: "nonsense"),
            CharacterDetailEpisode(id: "3", name: "Anatomy Park", air_date: "December 16, 2013", episode: "S01E03")
        ])

        let detail = try CharacterDetailEntityMapper().map(entity)

        #expect(detail.name == "Rick Sanchez")
        #expect(detail.episodes.map(\.name) == ["Pilot", "Anatomy Park"])
    }

    /// The API lists a character's episodes in broadcast order, which is the
    /// order a filmography reads in. Sorting an answer that is already sorted is
    /// only a chance to get it wrong.
    @Test("the API's order is preserved")
    func orderIsPreserved() throws {
        let entity = CharacterDetailEntity.make(episodes: [
            CharacterDetailEpisode(id: "3", name: "Third", air_date: "a", episode: "S02E05"),
            CharacterDetailEpisode(id: "1", name: "First", air_date: "b", episode: "S01E01"),
            CharacterDetailEpisode(id: "2", name: "Second", air_date: "c", episode: "S01E09")
        ])

        #expect(try CharacterDetailEntityMapper().map(entity).episodes.map(\.name)
                == ["Third", "First", "Second"])
    }
}
