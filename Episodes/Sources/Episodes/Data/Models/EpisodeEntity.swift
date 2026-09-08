//
//  EpisodeEntity.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Core
import Foundation
import Networking

/// Every property optional since GraphQL may answer `null`; required fields are the mapper's business.
@Document
struct EpisodeEntity: GraphQLDocumentConvertible, Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let name: String?
    /// Keeps the server's snake_case: it's both the selection key and the `Codable` coding key.
    let air_date: String?
    let episode: String?
    /// ISO 8601 with fractional seconds, e.g. `2021-10-15T17:00:24.105Z`.
    let created: String?
    let characters: [EpisodeCharacterEntity]?
}

/// Kept separate from the Characters feature's entity to avoid importing a whole module for three fields.
@Document
struct EpisodeCharacterEntity: GraphQLDocumentConvertible, Codable, Sendable, Identifiable, Hashable {
    let id: String?
    /// Not drawn: gives each avatar link a VoiceOver name instead of announcing "image".
    let name: String?
    let image: URL?
}
