//
//  CharactersListSectionMapperTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

import Combine
import Foundation
import Testing
@testable import Characters

@Suite("CharactersListSectionMapper")
@MainActor
struct CharactersListSectionMapperTests {

    @Test("loading hides everything")
    func loadingHidesTheList() {
        #expect(map(.make(isLoading: true, characters: [.rick])) == .hidden)
    }

    @Test("no page has ever landed hides the list rather than emptying it")
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

    @Test("an unfiltered empty list is still no results, with nothing to explain")
    func emptyWithoutAFilterHasNoSummary() {
        #expect(map(.make(characters: [])) == .empty(.noMatches(summary: nil, canClearFilters: false)))
    }

    @Test("rows are shown with the applied search text as the highlight")
    func visibleRowsCarryTheAppliedName() {
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

    // MARK: - Helpers

    private typealias DataModel = CharactersListSectionMapper.DataModel

    private func map(_ data: DataModel) -> CharactersListRenderModel {
        CharactersListSectionMapper(viewModel: StubCharactersListViewModel()).mapToRenderModel(data)
    }

    private func footer(for pagination: CharactersPaginationState) -> CharactersSectionFooter {
        guard case .visible(_, let footer, _) = map(.make(characters: [.rick], pagination: pagination)) else {
            return .none
        }
        return footer
    }
}

private extension CharactersListSectionMapper.DataModel {
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
}

extension CharacterModel {
    static let rick = make(id: "1", name: "Rick Sanchez")
    static let morty = make(id: "2", name: "Morty Smith")

    static func make(id: String, name: String) -> CharacterModel {
        CharacterModel(id: id,
                       name: name,
                       status: .alive,
                       species: "Human",
                       image: URL(string: "https://example.com/\(id).jpeg")!,
                       location: CharacterLocation(name: "Earth", dimension: nil))
    }
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
