//
//  EpisodesPageEntity.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking

/// One page of episodes exactly as the server sent it: `info` plus `results`.
///
/// This — not `[EpisodeModel]` — is what gets written to the cache. Caching the
/// *entity* keeps the stored bytes a faithful copy of the wire format, so the
/// mapper stays a pure, always-applied transformation rather than something that
/// ran once, months ago, against rules that have since changed. It also keeps
/// `info.next` and `info.pages` around, which is what the repository walks the
/// catalogue with and a flat model list has nowhere to put.
typealias EpisodesPageEntity = GraphQLPageResponse<EpisodeEntity>
