//
//  CharactersFilterBarSectionMapperTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

import Combine
import Testing
@testable import Characters

/// "How a status becomes the word Alive" is presentation logic, and this is the
/// test that can check it without a view hierarchy — which is the reason the bar
/// has a mapper at all.
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

    /// The search text is not a field, so it must never grow a chip the user
    /// could tap to remove something the search bar owns.
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
        // `type` is the one field that carries its label: a free-text sub-species
        // is indistinguishable from a species at a glance.
        #expect(render.chips.map(\.title) == ["Alive", "Human", "Type: parasite", "Female"])
    }

    @Test("a chip's identity is its field, so the bar does not re-animate")
    func chipIdentityIsTheField() {
        let render = map(CharactersFilter(status: .dead, gender: .genderless))

        #expect(render.chips.map(\.id) == [.status, .gender])
        #expect(render.chips.map(\.title) == ["Dead", "Genderless"])
    }

    /// The bar seeds the sheet from the applied filter, so the value has to
    /// travel with the chips rather than being reconstructed from their titles.
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

/// Held by the mapper, never read by it: every rule under test is a pure
/// function of the filter.
@MainActor
private final class StubCharactersFilterBarViewModel: CharactersFilterBarSectionViewModelContract {
    var filterPublisher: AnyPublisher<CharactersFilter, Never> { Just(.empty).eraseToAnyPublisher() }

    func apply(_ filter: CharactersFilter) {}
    func clear(_ field: CharactersFilter.Field) {}
    func clearAllFilters() {}
}
