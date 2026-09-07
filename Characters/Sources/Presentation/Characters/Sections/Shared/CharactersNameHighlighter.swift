//
//  CharactersNameHighlighter.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import SwiftUI

/// The searched substring, emphasised inside a character's name.
///
/// A free function in an enum namespace rather than a method on either section
/// view: both layouts highlight the same way, and a pure `String -> AttributedString`
/// transform is testable without a view hierarchy.
enum CharactersNameHighlighter {
    /// Matched case- and diacritic-insensitively so it lines up with what the
    /// server matched. A name that does not contain the text is returned plain
    /// rather than treated as an error: the server may well have matched on
    /// something this client cannot see.
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
