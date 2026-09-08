//
//  CharacterDetailEntity.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import Foundation
import Networking
import Core

/// One character, with everything the API knows about it, exactly as the server
/// describes it.
///
/// Every property is optional, which is the entity layer's whole job: GraphQL
/// can legally answer `null` for any field, and a non-optional here would turn a
/// single missing `species` into a decoding failure that blanks the whole
/// screen. Deciding which of these the detail cannot be drawn without is
/// `CharacterDetailEntityMapper`'s business.
///
/// The selection is *every* field the schema offers except two: `url`, which is
/// the REST address of the same record and is of no use to a client that speaks
/// GraphQL, and `created`, the API's own record-keeping timestamp, which says
/// nothing about the character. `episode` deliberately stops at the episode's own fields: an episode
/// carries its own `characters`, and following that edge would fetch the entire
/// cast of all fifty-one episodes to draw a list of names.
///
/// `air_date` keeps the server's snake_case spelling on purpose. The property
/// name is what `@Document` writes into the selection set and what `Codable`
/// synthesis uses as the coding key, so renaming it would need a `CodingKeys`
/// enum *and* a hand-written document. The domain model is where the
/// Swift-shaped name lives.
@Document
struct CharacterDetailEntity: GraphQLDocumentConvertible, Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let name: String?
    let status: String?
    let species: String?
    /// The subspecies or variant, e.g. `Parasite`. Blank far more often than it
    /// is filled in — the API sends `""` rather than `null` — which is why the
    /// mapper turns whitespace into `nil` rather than trusting the absence.
    let type: String?
    let gender: String?
    let origin: CharacterDetailPlace?
    let location: CharacterDetailPlace?
    let image: URL?
    let episode: [CharacterDetailEpisode]?
}

@Document
struct CharacterDetailPlace: GraphQLDocumentConvertible, Codable, Sendable, Hashable {
    let id: String?
    let name: String?
    /// A location's kind, e.g. `Planet` or `Space station`. Shown next to the
    /// name, so it is selected here rather than derived from the dimension.
    let type: String?
    let dimension: String?
}

@Document
struct CharacterDetailEpisode: GraphQLDocumentConvertible, Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let name: String?
    let air_date: String?
    /// The broadcast code, e.g. `S01E05`. Required by the mapper: it is what the
    /// row shows, and it is what the HBO Max join is keyed on once it has been
    /// split into a season and a number.
    let episode: String?
}

// MARK: - Debugging

/// Written out by hand rather than reflected. `@Document` skips computed
/// properties, so none of this reaches the selection set.

extension CharacterDetailEntity: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        CharacterDetailEntity
          id:       \(id ?? "nil")
          name:     \(name ?? "nil")
          status:   \(status ?? "nil")
          species:  \(species ?? "nil")
          type:     \(type ?? "nil")
          gender:   \(gender ?? "nil")
          origin:   \(origin?.debugDescription ?? "nil")
          location: \(location?.debugDescription ?? "nil")
          image:    \(image?.absoluteString ?? "nil")
          episode:  \(episode.map { "\($0.count)" } ?? "nil")
        """
    }
}

extension CharacterDetailPlace: CustomDebugStringConvertible {
    var debugDescription: String {
        "Place(name: \(name ?? "nil"), type: \(type ?? "nil"), dimension: \(dimension ?? "nil"))"
    }
}

extension CharacterDetailEpisode: CustomDebugStringConvertible {
    var debugDescription: String {
        "Episode(id: \(id ?? "nil"), name: \(name ?? "nil"), air_date: \(air_date ?? "nil"), episode: \(episode ?? "nil"))"
    }
}
