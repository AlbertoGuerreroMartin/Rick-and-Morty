//
//  EpisodesSectionEmptyReason.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

/// Why there is nothing to draw.
///
/// The two cases are told apart deliberately: "your search matched nothing" and
/// "we could not ask" look identical in an empty list, but one is answered by
/// changing the text and the other by tapping Retry. Collapsing them would offer
/// the user the wrong button.
enum EpisodesSectionEmptyReason: Equatable {
    /// The catalogue is on the device and nothing in it matched. `query` is the
    /// text to quote back, or `nil` when there was nothing loaded to search in
    /// the first place — blaming a search that is not the cause would be a lie.
    case noMatches(query: String?)
    case failed
}
