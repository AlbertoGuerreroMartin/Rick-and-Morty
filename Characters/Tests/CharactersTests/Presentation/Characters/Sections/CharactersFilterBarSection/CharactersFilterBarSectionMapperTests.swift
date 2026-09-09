//
//  CharactersFilterBarSectionMapperTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

import Testing
@testable import Characters

@Suite("CharactersFilterBarSectionMapper")
@MainActor
struct CharactersFilterBarSectionMapperTests {

    @Test("an empty filter has no chips and no count")
    func emptyFilterHasNoChips() {
        let render = map(.empty)

        #expect(render.activeCount == 0)
        #expect(render.chips.isEmpty)
        #expect(render.filter == .empty)
    }

    @Test("the search text never becomes a chip")
    func theSearchTextIsNotAChip() {
        let render = map(CharactersFilter(name: "rick"))

        #expect(render.activeCount == 0)
        #expect(render.chips.isEmpty)
    }

    @Test("one chip per active field, carrying the field it removes")
    func oneChipPerActiveField() {
        let filter = CharactersFilter(name: "rick",
                                      status: .alive,
                                      species: "human",
                                      type: "parasite",
                                      gender: .female)

        let render = map(filter)

        #expect(render.activeCount == 4)
        #expect(render.chips.map(\.field) == [.status, .species, .type, .gender])
        // `type` carries its label: a free-text sub-species is indistinguishable from a species.
        #expect(render.chips.map(\.title) == ["Alive", "Human", "Type: parasite", "Female"])
    }

    @Test("a chip's identity is its field, so the bar does not re-animate")
    func chipIdentityIsTheField() {
        let render = map(CharactersFilter(status: .dead, gender: .genderless))

        #expect(render.chips.map(\.id) == [.status, .gender])
        #expect(render.chips.map(\.title) == ["Dead", "Genderless"])
    }

    @Test("the applied filter travels with the render model")
    func theFilterIsCarriedThrough() {
        let filter = CharactersFilter(name: "rick", status: .alive)

        #expect(map(filter).filter == filter)
    }

    private func map(_ filter: CharactersFilter) -> CharactersFilterBarRenderModel {
        CharactersFilterBarSectionMapper(viewModel: StubCharactersFilterBarViewModel())
            .mapToRenderModel(filter)
    }
}
