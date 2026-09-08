//
//  EpisodeEntity.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Core
import Foundation
import Networking

/// One episode exactly as the server describes it.
///
/// Every property is optional, which is the entity layer's whole job: GraphQL
/// can legally answer `null` for any field, and a non-optional here would turn
/// a single missing `air_date` into a decoding failure that blanks the entire
/// page. Deciding which of these are actually *required* is the mapper's
/// business, one episode at a time — see `EpisodeEntityMapper`.
///
/// `air_date` keeps the server's snake_case spelling on purpose. The property
/// name is what `@Document` writes into the selection set and what `Codable`
/// synthesis uses as the coding key, so renaming it to `airDate` would need a
/// `CodingKeys` enum *and* a hand-written document — two places to keep in sync
/// for a name nobody outside this file ever reads. The domain model is where the
/// Swift-shaped name lives.
@Document
struct EpisodeEntity: GraphQLDocumentConvertible, Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let name: String?
    let air_date: String?
    /// The broadcast code, e.g. `S05E10`. Parsed into a season and a number by
    /// the mapper; the row shows it back verbatim.
    let episode: String?
    /// ISO 8601 with fractional seconds, e.g. `2021-10-15T17:00:24.105Z`.
    let created: String?
    /// Only `id` and `image` are selected. `@Document` peels the array and the
    /// optional off this type, so declaring it here is what produces the nested
    /// `characters { id image }` selection set — no hand-written document, and
    /// no chance of asking for a field the entity cannot decode.
    let characters: [EpisodeCharacterEntity]?
}

/// The sliver of a character an episode row needs: an id to key the avatar on
/// and a picture to draw.
///
/// A separate, deliberately tiny type rather than the Characters feature's
/// entity. Reusing that one would import a whole module for two fields, drag
/// its eleven-field selection set into every episode page — the catalogue is 51
/// episodes worth of `characters` arrays, so the wasted bytes are not
/// theoretical — and couple two features that have no reason to change together.
@Document
struct EpisodeCharacterEntity: GraphQLDocumentConvertible, Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let image: URL?
}
