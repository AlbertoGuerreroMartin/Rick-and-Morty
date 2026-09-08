//
//  CharacterDetailScreenGraph.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

/// The object graph owned by a `CharacterDetailScreen` instance. Built once per screen
/// identity and held through `Owned`, so every section gets the same publisher instance
/// across body evaluations.
@MainActor
struct CharacterDetailScreenGraph {
    let viewModel: CharacterDetailViewModel
    let headerMapper: CharacterDetailHeaderSectionMapper
    let infoMapper: CharacterDetailInfoSectionMapper
    let episodesMapper: CharacterDetailEpisodesSectionMapper
}
