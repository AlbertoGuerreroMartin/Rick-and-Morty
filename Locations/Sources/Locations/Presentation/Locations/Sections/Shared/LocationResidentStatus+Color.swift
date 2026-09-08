//
//  LocationResidentStatus+Color.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import SwiftUI

extension LocationResidentStatus {
    var color: Color {
        switch self {
        case .alive: .green
        case .dead: .red
        case .unknown: .gray
        }
    }
}
