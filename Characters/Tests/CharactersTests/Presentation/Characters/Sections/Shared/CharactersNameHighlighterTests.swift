//
//  CharactersNameHighlighterTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import SwiftUI
import Testing
@testable import Characters

@Suite("CharactersNameHighlighter")
struct CharactersNameHighlighterTests {

    @Test("the matched substring is the one emphasised run")
    func matchIsEmphasised() {
        let attributed = CharactersNameHighlighter.highlighted("Rick Sanchez", matching: "rick")

        #expect(String(attributed.characters) == "Rick Sanchez")
        #expect(emphasised(in: attributed) == ["Rick"])
    }

    @Test("matching ignores case and diacritics, like the server does")
    func matchIsCaseAndDiacriticInsensitive() {
        let attributed = CharactersNameHighlighter.highlighted("Rick Sánchez", matching: "SANCHEZ")

        #expect(emphasised(in: attributed) == ["Sánchez"])
    }

    @Test("a name without the text comes back plain rather than failing")
    func noMatchIsPlain() {
        let attributed = CharactersNameHighlighter.highlighted("Morty Smith", matching: "rick")

        #expect(String(attributed.characters) == "Morty Smith")
        #expect(emphasised(in: attributed).isEmpty)
    }

    @Test("blank search text highlights nothing")
    func blankHighlightIsPlain() {
        #expect(emphasised(in: CharactersNameHighlighter.highlighted("Rick Sanchez", matching: "   ")).isEmpty)
        #expect(emphasised(in: CharactersNameHighlighter.highlighted("Rick Sanchez", matching: nil)).isEmpty)
    }

    /// The text of every run that carries the highlight colour.
    private func emphasised(in attributed: AttributedString) -> [String] {
        attributed.runs
            .filter { $0.foregroundColor == .accentColor }
            .map { String(attributed[$0.range].characters) }
    }
}
