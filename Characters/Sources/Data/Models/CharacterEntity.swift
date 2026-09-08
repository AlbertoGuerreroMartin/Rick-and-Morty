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
struct CharacterEntity: GraphQLDocumentConvertible, Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let name: String?
    let status: String?
    let species: String?
    let image: URL?
    let origin: CharacterLocationEntity?
    let location: CharacterLocationEntity?
}

@Document
struct CharacterLocationEntity: GraphQLDocumentConvertible, Codable, Sendable, Hashable {
    let name: String?
    let dimension: String?
}
