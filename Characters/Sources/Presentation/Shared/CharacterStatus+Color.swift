//
//  CharacterStatus+Color.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import SwiftUI

extension CharacterStatus {
    var color: Color {
        switch self {
        case .alive: .green
        case .dead: .red
        case .unknown: .gray
        }
    }
}
