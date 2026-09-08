//
//  EpisodesPageEntity.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking

/// Cached instead of `[EpisodeModel]` so `info.next`/`info.pages`, which the repository walks
/// with, survive.
typealias EpisodesPageEntity = GraphQLPageResponse<EpisodeEntity>
