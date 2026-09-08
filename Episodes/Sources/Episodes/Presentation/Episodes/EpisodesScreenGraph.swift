//
//  EpisodesScreenGraph.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

/// The object graph owned by an `EpisodesScreen` instance, built once per screen identity.
@MainActor
struct EpisodesScreenGraph {
    /// Handed in by the app rather than owned: a tab root's stack must outlive the screen.
    let navigator: EpisodesNavigator
    let viewModel: EpisodesViewModel
    let listMapper: EpisodesListSectionMapper
}
