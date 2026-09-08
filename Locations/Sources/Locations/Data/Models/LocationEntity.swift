//
//  LocationEntity.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Core
import Foundation
import Networking

/// One location exactly as the server describes it. Every property is optional since GraphQL
/// can legally return `null` for any field; deciding which are actually required is the
/// mapper's job (see `LocationEntityMapper`). Omits only `created`, an API bookkeeping field.
@Document
struct LocationEntity: GraphQLDocumentConvertible, Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let name: String?
    /// API sends `""`, not `null`, when a location has no type; the mapper normalizes it.
    let type: String?
    let dimension: String?
    let residents: [LocationResidentEntity]?
}

/// The sliver of a character a location's resident strip needs. Kept separate from the
/// Characters feature's entity to avoid its full selection set and the cross-feature coupling.
@Document
struct LocationResidentEntity: GraphQLDocumentConvertible, Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let name: String?
    let status: String?
    let species: String?
    let image: URL?
}
