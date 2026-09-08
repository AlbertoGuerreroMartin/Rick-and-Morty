//
//  CharacterDetailEntity.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import Foundation
import Networking
import Core

/// One character, with everything the API knows about it, exactly as the server describes it.
/// Every property is optional since GraphQL may legally answer `null` for any field.
@Document
struct CharacterDetailEntity: GraphQLDocumentConvertible, Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let name: String?
    let status: String?
    let species: String?
    /// The subspecies or variant, e.g. `Parasite`. API sends `""`, not `null`; mapper turns blank into `nil`.
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
    /// A location's kind, e.g. `Planet` or `Space station`.
    let type: String?
    let dimension: String?
}

@Document
struct CharacterDetailEpisode: GraphQLDocumentConvertible, Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let name: String?
    /// snake_case kept: `@Document`/`Codable` synthesis uses the property name as the coding key.
    let air_date: String?
    /// The broadcast code, e.g. `S01E05`; split into season/number for the HBO Max join.
    let episode: String?
}
