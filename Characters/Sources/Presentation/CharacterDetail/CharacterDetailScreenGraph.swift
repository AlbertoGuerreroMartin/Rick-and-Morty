//
//  CharacterDetailScreenGraph.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

/// The object graph owned by a `CharacterDetailScreen` instance.
///
/// Built exactly once per screen identity and held by the screen through
/// `Owned`. It carries the view model *and* the three section mappers so every
/// section receives the very same publisher instance on each parent body
/// evaluation, avoiding re-subscription churn.
///
/// This is where the pattern earns itself on a *pushed* screen rather than a tab
/// root: a detail is created and destroyed every time the user taps a row and
/// comes back, and the graph's lifetime is the pushed screen's identity rather
/// than anything the factory has to track.
@MainActor
struct CharacterDetailScreenGraph {
    let viewModel: CharacterDetailViewModel
    let headerMapper: CharacterDetailHeaderSectionMapper
    let infoMapper: CharacterDetailInfoSectionMapper
    let episodesMapper: CharacterDetailEpisodesSectionMapper
}
