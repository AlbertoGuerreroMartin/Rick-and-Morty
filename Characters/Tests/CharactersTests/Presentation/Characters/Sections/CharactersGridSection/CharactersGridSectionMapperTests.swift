//
//  CharactersGridSectionMapperTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Foundation
import Testing
@testable import Characters

/// Case-for-case mirror of `CharactersListSectionMapperTests`: the grid has its own mapper
/// so it can diverge, and this suite checks that it has not.
@Suite("CharactersGridSectionMapper")
@MainActor
struct CharactersGridSectionMapperTests {

    @Test("loading hides everything")
    func loadingHidesTheGrid() {
        #expect(map(.make(isLoading: true, characters: [.rick])) == .hidden)
    }

    @Test("no page has ever landed hides the grid rather than emptying it")
    func nilCharactersIsHiddenNotEmpty() {
        #expect(map(.make(characters: nil)) == .hidden)
    }

    @Test("a failed load offers a retry, not a widen-your-search")
    func failedLoadIsItsOwnEmptyState() {
        let data = DataModel.make(characters: [],
                                  filter: CharactersFilter(name: "rick"),
                                  loadFailed: true)

        #expect(map(data) == .empty(.failed))
    }

    @Test("no results names the filter and offers to clear it")
    func noMatchesCarriesTheSummaryAndTheEscapeHatch() {
        let filter = CharactersFilter(name: "rick", status: .alive)
        let render = map(.make(characters: [], filter: filter))

        #expect(render == .empty(.noMatches(summary: "\u{201C}rick\u{201D} with Alive",
                                            canClearFilters: true)))
    }

    @Test("no results with only a search text cannot clear filters")
    func noMatchesWithoutFieldsHidesTheClearButton() {
        let render = map(.make(characters: [], filter: CharactersFilter(name: "rick")))

        #expect(render == .empty(.noMatches(summary: "\u{201C}rick\u{201D}", canClearFilters: false)))
    }

    @Test("an unfiltered empty grid is still no results, with nothing to explain")
    func emptyWithoutAFilterHasNoSummary() {
        #expect(map(.make(characters: [])) == .empty(.noMatches(summary: nil, canClearFilters: false)))
    }

    @Test("cells are shown with the applied search text as the highlight")
    func visibleCellsCarryTheAppliedName() {
        let render = map(.make(characters: [.rick],
                               pagination: .idle(nextPage: 2),
                               filter: CharactersFilter(name: "rick")))

        #expect(render == .visible(characters: [.rick], footer: .loadMore, highlight: "rick"))
    }

    @Test("the pagination state flattens into a footer")
    func paginationFlattensIntoAFooter() {
        #expect(footer(for: .idle(nextPage: 2)) == .loadMore)
        #expect(footer(for: .loading) == .loading)
        #expect(footer(for: .failed(nextPage: 2)) == .retry)
        #expect(footer(for: .end) == .none)
    }

    @Test("the grid agrees with the list on every outcome")
    func gridAgreesWithList() {
        let cases: [DataModel] = [
            .make(isLoading: true, characters: [.rick]),
            .make(characters: nil),
            .make(characters: [], loadFailed: true),
            .make(characters: [], filter: CharactersFilter(name: "rick", status: .alive)),
            .make(characters: [.rick, .morty], pagination: .failed(nextPage: 3), filter: CharactersFilter(name: "m"))
        ]
        let listMapper = CharactersListSectionMapper(viewModel: StubCharactersSectionViewModel())

        for data in cases {
            let list = listMapper.mapToRenderModel(data.asListData)
            let grid = map(data)
            switch (list, grid) {
            case (.hidden, .hidden):
                break
            case (.empty(let lhs), .empty(let rhs)):
                #expect(lhs == rhs)
            case (.visible(let listCharacters, let listFooter, let listHighlight),
                .visible(let gridCharacter, let gridFooter, let gridHighlight)):
                #expect(listCharacters == gridCharacter)
                #expect(listFooter == gridFooter)
                #expect(listHighlight == gridHighlight)
            default:
                Issue.record("List drew \(list) while grid drew \(grid)")
            }
        }
    }

    // MARK: - Helpers

    private typealias DataModel = CharactersGridSectionMapper.DataModel

    private func map(_ data: DataModel) -> CharactersGridRenderModel {
        CharactersGridSectionMapper(viewModel: StubCharactersSectionViewModel()).mapToRenderModel(data)
    }

    private func footer(for pagination: CharactersPaginationState) -> CharactersSectionFooter {
        guard case .visible(_, let footer, _) = map(.make(characters: [.rick], pagination: pagination)) else {
            return .none
        }
        return footer
    }
}

private extension CharactersGridSectionMapper.DataModel {
    static func make(isLoading: Bool = false,
                     characters: [CharacterModel]? = [],
                     pagination: CharactersPaginationState = .end,
                     filter: CharactersFilter = .empty,
                     loadFailed: Bool = false) -> Self {
        Self(isLoading: isLoading,
             characters: characters,
             pagination: pagination,
             filter: filter,
             loadFailed: loadFailed)
    }

    var asListData: CharactersListSectionMapper.DataModel {
        .init(isLoading: isLoading,
              characters: characters,
              pagination: pagination,
              filter: filter,
              loadFailed: loadFailed)
    }
}
