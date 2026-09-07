//
//  CharactersLayout.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

/// How the characters screen lays its results out.
///
/// Screen state, not view model state. The list and the grid draw the same
/// data — same rows, same footer, same empty states — so the choice between
/// them changes nothing about what is loaded, filtered or paginated. Routing it
/// through a publisher would make the view model responsible for a piece of UI
/// it never needs to reason about, exactly as with the filter sheet's
/// presentation flag.
enum CharactersLayout: Equatable, Sendable {
    case list
    case grid

    var toggled: CharactersLayout {
        switch self {
        case .list: .grid
        case .grid: .list
        }
    }

    /// The toggle button shows the layout the tap *leads to*, not the current
    /// one, which is how the grid/list buttons in Files and Photos behave.
    var toggleSystemImage: String {
        switch self {
        case .list: "square.grid.2x2"
        case .grid: "list.bullet"
        }
    }

    var toggleTitle: String {
        switch self {
        case .list: "Show as grid"
        case .grid: "Show as list"
        }
    }
}
