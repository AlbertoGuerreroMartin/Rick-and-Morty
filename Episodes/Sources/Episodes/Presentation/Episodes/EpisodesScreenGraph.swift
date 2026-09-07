//
//  EpisodesScreenGraph.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

/// The object graph owned by an `EpisodesScreen` instance.
///
/// Built exactly once per screen identity and held by the screen through
/// `Owned`. It carries the view model *and* the section mapper so the section
/// receives the very same publisher instance on each parent body evaluation,
/// avoiding re-subscription churn.
@MainActor
struct EpisodesScreenGraph {
    let viewModel: EpisodesViewModel
    let listMapper: EpisodesListSectionMapper
}
