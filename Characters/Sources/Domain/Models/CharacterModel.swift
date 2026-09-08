//
//  CharacterModel.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Foundation

struct CharacterModel: Sendable, Hashable {
    let id: String
    let name: String
    let status: CharacterStatus
    let species: String
    let image: URL
    let location: CharacterLocation
}

enum CharacterStatus: String, Sendable, Hashable, CaseIterable {
    case alive
    case dead
    case unknown

    init?(rawValue: String) {
        // API sends mixed casing; unrecognized values fall back to .unknown.
        switch rawValue.lowercased() {
        case "alive": self = .alive
        case "dead": self = .dead
        default: self = .unknown
        }
    }
}

struct CharacterLocation: Sendable, Hashable {
    let name: String
    let dimension: String?
}
