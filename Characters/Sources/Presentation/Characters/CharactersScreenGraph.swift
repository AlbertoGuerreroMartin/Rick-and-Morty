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
///
/// Both results mappers live here even though only one section is on screen at
/// a time: a mapper is a cheap pair of publisher pipelines, and building one on
/// every layout toggle would make the toggle the one place a section gets a
/// fresh publisher.
@MainActor
struct CharactersScreenGraph {
    let viewModel: CharactersViewModel
    let listMapper: CharactersListSectionMapper
    let gridMapper: CharactersGridSectionMapper
    let filterBarMapper: CharactersFilterBarSectionMapper
}
