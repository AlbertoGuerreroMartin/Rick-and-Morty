//
//  CharacterEntity.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import Foundation
import Networking
import Core

@Document
struct CharacterEntity: GraphQLDocumentConvertible, Decodable, Identifiable, Hashable {
    let id: String?
    let name: String?
    let status: String?
    let species: String?
    let image: URL?
    let origin: CharacterLocationEntity?
    let location: CharacterLocationEntity?
}

@Document
struct CharacterLocationEntity: GraphQLDocumentConvertible, Decodable, Hashable {
    let name: String?
    let dimension: String?
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
          status:   \(status)
          species:  \(species)
          image:    \(image?.absoluteString ?? "nil")
          origin:   \(origin?.debugDescription ?? "nil")
          location: \(location?.debugDescription ?? "nil")
        """
    }
}

extension CharacterLocationEntity: CustomDebugStringConvertible {
    var debugDescription: String {
        "Place(name: \(name ?? "nil"), dimension: \(dimension ?? "nil"))"
    }
}
