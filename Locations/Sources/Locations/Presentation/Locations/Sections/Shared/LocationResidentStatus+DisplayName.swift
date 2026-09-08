//
//  LocationResidentStatus+DisplayName.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation

extension LocationResidentStatus {
    /// Localized label; `rawValue` is the API's wire value, not user-facing copy.
    var displayName: String {
        switch self {
        case .alive: String(localized: "Alive", bundle: .module)
        case .dead: String(localized: "Dead", bundle: .module)
        case .unknown: String(localized: "Unknown", bundle: .module)
        }
    }
}
