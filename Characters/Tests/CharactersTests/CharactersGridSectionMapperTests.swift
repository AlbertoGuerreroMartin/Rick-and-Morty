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

/// A case-for-case mirror of `CharactersListSectionMapperTests`. The grid has
/// its own mapper so it can diverge, and this suite is what says it has not:
/// a user toggling layouts must never meet a spinner in one and an empty state
/// in the other.
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

    /// The equivalence the two mappers promise, checked directly rather than
    /// left to the reader comparing two suites: the same data yields the same
    /// shape from both, for every kind of outcome.
    @Test("the grid agrees with the list on every outcome")
    func gridAgreesWithList() {
        let cases: [DataModel] = [
            .make(isLoading: true, characters: [.rick]),
            .make(characters: nil),
            .make(characters: [], loadFailed: true),
            .make(characters: [], filter: CharactersFilter(name: "rick", status: .alive)),
            .make(characters: [.rick, .morty], pagination: .failed(nextPage: 3), filter: CharactersFilter(name: "m"))
        ]
        let listMapper = CharactersListSectionMapper(viewModel: StubCharactersListViewModel())

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
        CharactersGridSectionMapper(viewModel: StubCharactersGridViewModel()).mapToRenderModel(data)
    }

    private func footer(for pagination: CharactersPaginationState) -> CharactersSectionFooter {
        guard case .visible(_, let footer, _) = map(.make(characters: [.rick], pagination: pagination)) else {
            return .none
        }
        return footer
    }
}

private extension CharactersGridSectionMapper.DataModel {
    /// Named defaults for "nothing special is going on", so each test states
    /// only the one thing it is about.
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

/// The mapper needs a view model to hold, but not to read. The publishers are
/// here to satisfy the contract and nothing else.
@MainActor
private final class StubCharactersGridViewModel: CharactersGridSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { Just(false).eraseToAnyPublisher() }
    var charactersPublisher: AnyPublisher<[CharacterModel]?, Never> { Just(nil).eraseToAnyPublisher() }
    var paginationPublisher: AnyPublisher<CharactersPaginationState, Never> {
        Just(.end).eraseToAnyPublisher()
    }
    var filterPublisher: AnyPublisher<CharactersFilter, Never> { Just(.empty).eraseToAnyPublisher() }
    var loadFailedPublisher: AnyPublisher<Bool, Never> { Just(false).eraseToAnyPublisher() }

    func loadNextPage() async {}
    func retryLoad() {}
    func clearAllFilters() {}
}

@MainActor
private final class StubCharactersListViewModel: CharactersListSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { Just(false).eraseToAnyPublisher() }
    var charactersPublisher: AnyPublisher<[CharacterModel]?, Never> { Just(nil).eraseToAnyPublisher() }
    var paginationPublisher: AnyPublisher<CharactersPaginationState, Never> {
        Just(.end).eraseToAnyPublisher()
    }
    var filterPublisher: AnyPublisher<CharactersFilter, Never> { Just(.empty).eraseToAnyPublisher() }
    var loadFailedPublisher: AnyPublisher<Bool, Never> { Just(false).eraseToAnyPublisher() }

    func loadNextPage() async {}
    func retryLoad() {}
    func clearAllFilters() {}
}
