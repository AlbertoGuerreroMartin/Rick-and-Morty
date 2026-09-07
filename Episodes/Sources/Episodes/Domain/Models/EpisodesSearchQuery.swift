//
//  EpisodesSearchQuery.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// What the user typed into the episodes search bar, and the rule for what it
/// matches.
///
/// A value type rather than a bare `String?` for the same reason `CharactersFilter`
/// is one: it normalizes on the way in, so `"   "` — which would match nothing
/// and empty the screen for a user who only pressed space — is unrepresentable,
/// and it carries the *matching rule* next to the text so the section mapper,
/// the tests and any future section all agree on what "matches" means.
///
/// The rule is a substring match, case- and diacritic-insensitive, against three
/// fields:
///
/// - **name** — the obvious one, `"pilot"`, `"rickshank"`.
/// - **code** — so `"S03"` narrows to a season and `"E01"` to every premiere.
/// - **air date** — the API's own wording, so `"2013"` or `"December"` works,
///   which is how people actually remember when something aired.
///
/// Deliberately *not* searched: the character ids and image URLs, which are
/// opaque strings no user has ever seen and which would produce matches nobody
/// could explain (typing `"12"` matching an episode because a character with id
/// 12 appears in it); and `created`, which is the API's own bookkeeping
/// timestamp, is never shown on screen, and would make a search for `"2021"`
/// return episodes from 2013.
struct EpisodesSearchQuery: Sendable, Hashable {

    /// The trimmed text, or `nil` when the user has typed nothing meaningful.
    let text: String?

    /// No search at all: every episode matches.
    static let empty = EpisodesSearchQuery()

    init(text: String? = nil) {
        self.text = Self.normalized(text)
    }

    var isEmpty: Bool {
        text == nil
    }

    /// - Returns: `true` when `episode` should stay on screen. An empty query
    ///   matches everything, which is what keeps the caller free of a special
    ///   case for "not searching".
    func matches(_ episode: EpisodeModel) -> Bool {
        guard let text else { return true }
        return contains(episode.name, text)
            || contains(episode.code, text)
            || contains(episode.airDate, text)
    }

    /// `localizedStandardContains` semantics, spelled out: case- and
    /// diacritic-insensitive. Someone searching for `"rickshank"` should find
    /// "The Rickshank Rickdemption", and someone typing without accents should
    /// still find a title that carries them.
    private func contains(_ haystack: String, _ needle: String) -> Bool {
        haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    /// Trims whitespace and newlines, and turns the blank result into `nil`.
    ///
    /// Every text that reaches a query goes through here, so `""` and `"  "` can
    /// never become a constraint that matches nothing.
    static func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
