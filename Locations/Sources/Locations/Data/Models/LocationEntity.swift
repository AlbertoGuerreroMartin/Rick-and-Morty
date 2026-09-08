//
//  LocationEntity.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Core
import Foundation
import Networking

/// One location exactly as the server describes it.
///
/// Every property is optional, which is the entity layer's whole job: GraphQL
/// can legally answer `null` for any field, and a non-optional here would turn a
/// single missing `dimension` into a decoding failure that blanks the entire
/// page. Deciding which of these are actually *required* is the mapper's
/// business, one location at a time — see `LocationEntityMapper`.
///
/// **Everything the schema offers except `created`.** A location is `id`,
/// `name`, `type`, `dimension` and its `residents`, and all five are here. The
/// one field left out is `created`, the API's own record-keeping timestamp: it
/// says when the row was written into rickandmortyapi's database, which is a
/// fact about the API and not about the place, and nothing on this screen could
/// honestly show it. Leaving it out of the `@Document` selection is also the
/// cheaper answer — 126 locations' worth of a string nobody reads.
@Document
struct LocationEntity: GraphQLDocumentConvertible, Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let name: String?
    /// What kind of place it is, e.g. `Planet`, `Space station`. The API sends
    /// `""` — not `null` — when it has none, which is why the mapper normalizes
    /// it rather than trusting the optionality here.
    let type: String?
    let dimension: String?
    /// Only `id` and `image` are selected. `@Document` peels the array and the
    /// optional off this type, so declaring it here is what produces the nested
    /// `residents { id image }` selection set — no hand-written document, and no
    /// chance of asking for a field the entity cannot decode.
    let residents: [LocationResidentEntity]?
}

/// The sliver of a character a location's resident strip needs: an id to key the
/// avatar on and a picture to draw.
///
/// A separate, deliberately tiny type rather than the Characters feature's
/// entity. Reusing that one would import a whole module for two fields, drag its
/// eleven-field selection set into every location page — the Citadel of Ricks
/// alone has hundreds of residents, so the wasted bytes are not theoretical —
/// and couple two features that have no reason to change together.
@Document
struct LocationResidentEntity: GraphQLDocumentConvertible, Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let name: String?
    let image: URL?
}
