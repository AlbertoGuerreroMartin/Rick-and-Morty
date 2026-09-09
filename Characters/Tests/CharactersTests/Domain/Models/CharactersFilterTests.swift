//
//  CharactersFilterTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

import Testing
@testable import Characters

/// `CharactersFilter` drives the request, cache key and chips, so normalization and "active" are pinned here.
@Suite("CharactersFilter")
struct CharactersFilterTests {

    @Test("blank text normalizes to nil")
    func blankTextNormalizesToNil() {
        #expect(CharactersFilter.normalized(nil) == nil)
        #expect(CharactersFilter.normalized("") == nil)
        #expect(CharactersFilter.normalized("   ") == nil)
        #expect(CharactersFilter.normalized("\n \t") == nil)
        #expect(CharactersFilter.normalized("  rick  ") == "rick")
    }

    @Test("the initializer trims every free-text field")
    func initializerNormalizesFreeText() {
        let filter = CharactersFilter(name: "  Rick  ", species: "   ", type: " Parasite ")

        #expect(filter.name == "Rick")
        #expect(filter.species == nil)
        #expect(filter.type == "Parasite")
    }

    @Test("a field-by-field draft is tidied by normalized()")
    func normalizedTidiesADraft() {
        var draft = CharactersFilter.empty
        draft.species = "  Human "
        draft.type = "  "

        #expect(draft.normalized() == CharactersFilter(species: "Human"))
    }

    @Test("only the four fields count as active, never the search text")
    func activeFieldCountIgnoresTheSearchText() {
        #expect(CharactersFilter.empty.activeFieldCount == 0)
        #expect(CharactersFilter.empty.hasActiveFields == false)
        #expect(CharactersFilter(name: "rick").activeFieldCount == 0)
        #expect(CharactersFilter(name: "rick", status: .alive).activeFieldCount == 1)
        #expect(CharactersFilter(status: .alive, species: "Human", type: "Clone", gender: .female)
            .activeFieldCount == 4)
    }

    @Test("isEmpty covers the search text too")
    func isEmptyCoversEverything() {
        #expect(CharactersFilter.empty.isEmpty)
        #expect(CharactersFilter(name: "rick").isEmpty == false)
        #expect(CharactersFilter(status: .alive).isEmpty == false)
    }

    @Test("clearing a field leaves the others and the search text alone")
    func clearDropsExactlyOneField() {
        var filter = CharactersFilter(name: "rick", status: .alive, species: "Human", gender: .female)

        filter.clear(.status)

        #expect(filter == CharactersFilter(name: "rick", species: "Human", gender: .female))
    }

    @Test("clearingFields keeps the search text")
    func clearingFieldsKeepsTheName() {
        let filter = CharactersFilter(name: "rick", status: .alive, species: "Human",
                                      type: "Clone", gender: .female)

        #expect(filter.clearingFields() == CharactersFilter(name: "rick"))
    }

    @Test("summary names everything that was asked for")
    func summaryDescribesTheWholeFilter() {
        #expect(CharactersFilter.empty.summary == nil)
        #expect(CharactersFilter(name: "rick").summary == "\u{201C}rick\u{201D}")
        #expect(CharactersFilter(status: .alive, species: "human").summary == "Alive · Human")
        #expect(CharactersFilter(type: "parasite").summary == "Type: parasite")
        #expect(CharactersFilter(name: "rick", status: .alive, species: "Human").summary
                == "\u{201C}rick\u{201D} with Alive · Human")
    }
}
