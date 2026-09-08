//
//  CharacterModel.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import SwiftUI

struct CharacterModel: Sendable, Hashable {
    let id: String
    let name: String
    let status: CharacterStatus
    let species: String
    let image: URL
    let location: CharacterLocation
}

/// `CaseIterable` so the filter sheet's picker can list the statuses without a
/// second, hand-maintained array that could drift from the enum.
enum CharacterStatus: String, Sendable, Hashable, CaseIterable {
    case alive
    case dead
    case unknown

    init?(rawValue: String) {
        // API sends some values upper camel cased, and some lowercased. Lowercase by default to avoid false parsing errors.
        // Also fallback to unknown case to cover from new values.
        switch rawValue.lowercased() {
        case "alive": self = .alive
        case "dead": self = .dead
        default: self = .unknown
        }
    }

    var color: Color {
        switch self {
        case .alive: .green
        case .dead: .red
        case .unknown: .gray
        }
    }
}

struct CharacterLocation: Sendable, Hashable {
    let name: String
    let dimension: String?
}
