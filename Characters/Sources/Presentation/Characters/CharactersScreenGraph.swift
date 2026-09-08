//
//  CharactersScreenGraph.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

/// The object graph owned by a `CharactersScreen` instance. Built once per screen identity
/// and held through `Owned`, so every section gets the same publisher instance across
/// body evaluations.
@MainActor
struct CharactersScreenGraph {
    /// Handed in by the app rather than owned here: the tab's stack must outlive the screen.
    /// See `CharactersNavigator`.
    let navigator: CharactersNavigator
    let viewModel: CharactersViewModel
    let listMapper: CharactersListSectionMapper
    let gridMapper: CharactersGridSectionMapper
    let filterBarMapper: CharactersFilterBarSectionMapper
}
