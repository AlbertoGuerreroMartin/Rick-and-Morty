//
//  CharactersLayout.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// How the characters screen lays its results out. Screen state, not view model state: the
/// list and grid draw the same data, so the choice changes nothing about loading or filtering.
enum CharactersLayout: Equatable, Sendable {
    case list
    case grid

    var toggled: CharactersLayout {
        switch self {
        case .list: .grid
        case .grid: .list
        }
    }

    /// Shows the layout the tap leads to, not the current one (as in Files and Photos).
    var toggleSystemImage: String {
        switch self {
        case .list: "square.grid.2x2"
        case .grid: "list.bullet"
        }
    }

    var toggleTitle: String {
        switch self {
        case .list: String(localized: "Show as grid", bundle: .module)
        case .grid: String(localized: "Show as list", bundle: .module)
        }
    }
}
