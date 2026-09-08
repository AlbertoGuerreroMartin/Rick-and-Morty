//
//  CharacterGender+DisplayName.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation

extension CharacterGender {
    /// Localized label; `rawValue` is the API's wire value, not user-facing copy.
    var displayName: String {
        switch self {
        case .female: String(localized: "Female", bundle: .module)
        case .male: String(localized: "Male", bundle: .module)
        case .genderless: String(localized: "Genderless", bundle: .module)
        case .unknown: String(localized: "Unknown", bundle: .module)
        }
    }
}
