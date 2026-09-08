//
//  EpisodesSectionEmptyReason.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

/// "Search matched nothing" and "we could not ask" look identical but need different buttons.
enum EpisodesSectionEmptyReason: Equatable {
    /// `query` is `nil` when there was nothing loaded to search in the first place.
    case noMatches(query: String?)
    case failed
}
