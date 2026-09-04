//
//  CharacterDetailEntity.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import Foundation
import Networking
import Core

@Document
struct CharacterDetailEntity: GraphQLDocumentConvertible, Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let status: String
    let species: String
    let type: String
    let gender: String
    let origin: CharacterDetailPlace?
    let location: CharacterDetailPlace?
    let image: URL?
    let episode: [CharacterDetailEpisode]
}

@Document
struct CharacterDetailPlace: GraphQLDocumentConvertible, Decodable, Hashable {
    let id: String?
    let name: String?
    let dimension: String?
}

@Document
struct CharacterDetailEpisode: GraphQLDocumentConvertible, Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let air_date: String?
}


// MARK: - Debugging

/// Written out by hand rather than reflected. `@Document` skips computed
/// properties, so none of this reaches the selection set.

extension CharacterDetailEntity: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        CharacterDetailEntity
          id:       \(id)
          name:     \(name)
          status:     \(status)
          species:  \(species)
          type:     \(type)
          gender:  \(gender)
          origin:  \(origin?.debugDescription ?? "nil")
          location:  \(location?.debugDescription ?? "nil")
          image:    \(image?.absoluteString ?? "nil")
          episode:    \(episode.count)
        """
    }
}

extension CharacterDetailPlace: CustomDebugStringConvertible {
    var debugDescription: String {
        "Place(name: \(name ?? "nil"), dimension: \(dimension ?? "nil"))"
    }
}

extension CharacterDetailEpisode: CustomDebugStringConvertible {
    var debugDescription: String {
        "Episode(id: \(id), name: \(name), air_date: \(air_date ?? "nil"))"
    }
}
