//
//  CharactersLayoutTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Testing
@testable import Characters

@Suite("CharactersLayout")
struct CharactersLayoutTests {

    @Test("toggling alternates between the two layouts")
    func toggleAlternates() {
        #expect(CharactersLayout.list.toggled == .grid)
        #expect(CharactersLayout.grid.toggled == .list)
        #expect(CharactersLayout.list.toggled.toggled == .list)
    }

    @Test("the toggle button differs per layout")
    func toggleButtonIsDistinct() {
        #expect(CharactersLayout.list.toggleSystemImage != CharactersLayout.grid.toggleSystemImage)
        #expect(CharactersLayout.list.toggleTitle != CharactersLayout.grid.toggleTitle)
    }
}
