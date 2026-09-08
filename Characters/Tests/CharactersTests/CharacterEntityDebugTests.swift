//
//  CharacterEntityDebugTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Characters

/// The `debugDescription`s are written out by hand rather than reflected, which
/// is what keeps them out of the `@Document` selection set — and also what makes
/// them the one part of an entity that can silently rot: a field added above and
/// forgotten below shows up as a developer printing a character and not finding
/// the property they were looking for.
///
/// They also have to survive every field being `nil`, which is the state they
/// are most likely to be printed in: the reason someone reaches for one is
/// usually that the server answered with less than expected.
@Suite("Entity debug descriptions")
struct CharacterEntityDebugTests {

    @Test("a character summarises every field it carries")
    func characterDescribesItself() {
        let description = CharacterEntity.make(name: "Rick Sanchez").debugDescription

        #expect(description.contains("CharacterEntity"))
        #expect(description.contains("Rick Sanchez"))
        #expect(description.contains("Alive"))
        #expect(description.contains("Human"))
        #expect(description.contains("example.com"))
        #expect(description.contains("Earth"))
    }

    @Test("an empty character describes its absent fields rather than crashing")
    func emptyCharacterDescribesItself() {
        let description = CharacterEntity(id: nil, name: nil, status: nil, species: nil,
                                          image: nil, origin: nil, location: nil).debugDescription

        #expect(description.contains("nil"))
    }

    @Test("a location describes itself")
    func locationDescribesItself() {
        #expect(CharacterLocationEntity(name: "Earth", dimension: "C-137")
            .debugDescription == "Place(name: Earth, dimension: C-137)")
        #expect(CharacterLocationEntity(name: nil, dimension: nil)
            .debugDescription.contains("nil"))
    }

    /// The detail is the biggest entity in the feature and the one whose
    /// description is worth having: eleven fields across three types, printed as
    /// counts rather than as a hundred lines of filmography.
    @Test("a detail summarises every field it carries")
    func detailDescribesItself() {
        let description = CharacterDetailEntity.make(type: "Parasite").debugDescription

        #expect(description.contains("CharacterDetailEntity"))
        #expect(description.contains("Rick Sanchez"))
        #expect(description.contains("Alive"))
        #expect(description.contains("Human"))
        #expect(description.contains("Parasite"))
        #expect(description.contains("Male"))
        #expect(description.contains("Earth (C-137)"))
        #expect(description.contains("Citadel of Ricks"))
        // The filmography as a count: a character can appear in fifty episodes,
        // and printing them all would bury whatever the description was printed
        // to explain.
        #expect(description.contains("episode:  2"))
    }

    @Test("an empty detail describes its absent fields rather than crashing")
    func emptyDetailDescribesItself() {
        let description = CharacterDetailEntity.make(id: nil, name: nil, status: nil, species: nil,
                                                     type: nil, gender: nil, origin: nil, location: nil,
                                                     image: nil, episodes: nil).debugDescription

        #expect(description.contains("nil"))
    }

    @Test("a place and an episode describe themselves")
    func nestedEntitiesDescribeThemselves() {
        let place = CharacterDetailPlace(id: "1", name: "Earth", type: "Planet", dimension: "C-137")
        #expect(place.debugDescription == "Place(name: Earth, type: Planet, dimension: C-137)")
        #expect(CharacterDetailPlace(id: nil, name: nil, type: nil, dimension: nil)
            .debugDescription.contains("nil"))

        let episode = CharacterDetailEpisode(id: "1", name: "Pilot",
                                             air_date: "December 2, 2013", episode: "S01E01")
        #expect(episode.debugDescription
                == "Episode(id: 1, name: Pilot, air_date: December 2, 2013, episode: S01E01)")
        #expect(CharacterDetailEpisode(id: nil, name: nil, air_date: nil, episode: nil)
            .debugDescription.contains("nil"))
    }
}
