//
//  EpisodesSearchQuery.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// Normalizes on the way in so `"   "` cannot empty the screen. Matches case/diacritic-insensitively
/// against name, code and air date; deliberately excludes character ids/images and `created`.
struct EpisodesSearchQuery: Sendable, Hashable {

    let text: String?

    static let empty = EpisodesSearchQuery()

    init(text: String? = nil) {
        self.text = Self.normalized(text)
    }

    var isEmpty: Bool {
        text == nil
    }

    func matches(_ episode: EpisodeModel) -> Bool {
        guard let text else { return true }
        return contains(episode.name, text)
            || contains(episode.code, text)
            || contains(episode.airDate, text)
    }

    private func contains(_ haystack: String, _ needle: String) -> Bool {
        haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    static func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
