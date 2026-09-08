//
//  HBOMaxLinks.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// Where an episode sits in the catalogue: its season and its number within it.
///
/// A two-field key rather than the episode's id or its `S01E05` code, because
/// the two sides of the join have neither in common. JustWatch numbers episodes
/// and rickandmortyapi codes them, and the pair of integers is the one thing
/// both agree on — deriving a code from JustWatch's numbers would mean inventing
/// a format for the express purpose of parsing it back out.
///
/// The Characters copy of the Episodes value: feature packages stay independent,
/// so the twenty lines are duplicated rather than shared through a module both
/// would then depend on. See `JustWatchShowOffersQuery`.
struct EpisodeNumber: Hashable, Sendable {
    let season: Int
    /// The episode's number *within its season*.
    let number: Int
}

/// The HBO Max link for each episode that has one.
///
/// A value type over the dictionary rather than the dictionary itself, so the
/// key stays this type's business: callers ask "the link for season 1, episode
/// 5" and never construct an `EpisodeNumber`, which means the join can change
/// what it keys on without touching the use case or the tests that read it.
///
/// Missing is the normal case, not an error. A country where the show is not on
/// HBO Max, an episode the catalogue has not listed yet, or a JustWatch request
/// that simply failed all arrive here as the same thing — no link — and the row
/// draws without a button.
struct HBOMaxLinks: Sendable, Equatable {
    private let urls: [EpisodeNumber: URL]

    /// What a failed or unhelpful lookup produces. The screen renders
    /// identically, minus the buttons.
    static let empty = HBOMaxLinks(urls: [:])

    init(urls: [EpisodeNumber: URL]) {
        self.urls = urls
    }

    var isEmpty: Bool {
        urls.isEmpty
    }

    /// How many episodes have a link. Not shown anywhere; it is what makes a
    /// silently empty join visible in a test or a log line.
    var count: Int {
        urls.count
    }

    /// - Returns: the link for that episode, or `nil` when there is none.
    func url(season: Int, number: Int) -> URL? {
        urls[EpisodeNumber(season: season, number: number)]
    }
}
