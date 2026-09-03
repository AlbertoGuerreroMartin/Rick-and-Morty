//
//  CharacterEntity.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import Foundation
import Networking
import SwiftUI
import Utils

@Document
struct CharacterEntity: GraphQLDocumentConvertible, Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let status: Status
    let species: String
    let image: URL?
    let origin: CharacterPlace?
    let location: CharacterPlace?
}

@Document
struct CharacterPlace: GraphQLDocumentConvertible, Decodable, Hashable {
    let name: String?
    let dimension: String?
}

/// The API sends `status` as one of "Alive" / "Dead" / "unknown".
///
/// Decoding through an enum with a fallback case matters: a server is free to add
/// a new value to an enum without it being a breaking change, so a strict
/// `RawRepresentable` decode would start throwing on data that is perfectly valid.
enum Status: String, Decodable, Hashable {
    case alive = "Alive"
    case dead = "Dead"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Status(rawValue: raw) ?? .unknown
    }

    var color: Color {
        switch self {
        case .alive: .green
        case .dead: .red
        case .unknown: .gray
        }
    }
}

// MARK: - Debugging

/// Written out by hand rather than reflected. `@Document` skips computed
/// properties, so none of this reaches the selection set.
extension CharacterEntity: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        CharacterEntity
          id:       \(id)
          name:     \(name)
          status:   \(status.rawValue)
          species:  \(species)
          image:    \(image?.absoluteString ?? "nil")
          origin:   \(origin?.debugDescription ?? "nil")
          location: \(location?.debugDescription ?? "nil")
        """
    }
}

extension CharacterPlace: CustomDebugStringConvertible {
    var debugDescription: String {
        "Place(name: \(name ?? "nil"), dimension: \(dimension ?? "nil"))"
    }
}
