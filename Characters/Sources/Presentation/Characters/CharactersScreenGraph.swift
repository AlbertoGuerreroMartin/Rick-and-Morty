//
//  CharactersScreenGraph.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

/// The object graph owned by a `CharactersScreen` instance.
///
/// Built exactly once per screen identity and held by the screen through
/// `Owned`. It carries the view model *and* the section mappers so every
/// section receives the very same publisher instance on each parent body
/// evaluation, avoiding re-subscription churn.
@MainActor
struct CharactersScreenGraph {
    let viewModel: CharactersViewModel
    let listMapper: CharactersListSectionMapper
}
