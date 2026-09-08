//
//  CharactersNameHighlighter.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import SwiftUI

/// The searched substring, emphasised inside a character's name.
enum CharactersNameHighlighter {
    /// Case- and diacritic-insensitive, matching the server.
    static func highlighted(_ name: String, matching highlight: String?) -> AttributedString {
        var attributed = AttributedString(name)
        guard let highlight = CharactersFilter.normalized(highlight),
              let matched = name.range(of: highlight, options: [.caseInsensitive, .diacriticInsensitive]),
              let range = Range(matched, in: attributed) else {
            return attributed
        }

        attributed[range].font = .headline.bold()
        attributed[range].foregroundColor = .accentColor
        return attributed
    }
}
