//
//  CharactersGridSectionMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Core
import Foundation

enum CharactersGridRenderModel: Equatable {
    case hidden
    /// `highlight` is the substring to emphasise in each cell's name, or `nil`
    /// when there is no search text.
    case visible(characters: [CharacterModel], footer: CharactersSectionFooter, highlight: String?)
    case empty(CharactersSectionEmptyReason)
}

protocol CharactersGridSectionMapperContract: SectionMapperContract {}

/// The grid's own mapper. Its rules are the list's rules, on purpose: the two
/// layouts are two drawings of one result, and a user toggling between them
/// must never see the spinner in one and an empty state in the other. That
/// equivalence is asserted by `CharactersGridSectionMapperTests` mirroring the
/// list's suite case for case.
@MainActor
final class CharactersGridSectionMapper: CharactersGridSectionMapperContract {
    typealias ViewModel = CharactersGridSectionViewModelContract
    typealias RenderModel = CharactersGridRenderModel

    struct DataModel {
        let isLoading: Bool
        let characters: [CharacterModel]?
        let pagination: CharactersPaginationState
        let filter: CharactersFilter
        let loadFailed: Bool
    }

    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    /// Five publishers through two nested `combineLatest`s; see the list mapper
    /// for why the view model does not grow a single pre-combined state.
    func dataPublisher(_ viewModel: ViewModel) -> AnyPublisher<DataModel, Never> {
        let grid = viewModel.loadingPublisher
            .combineLatest(viewModel.charactersPublisher, viewModel.paginationPublisher)
        let query = viewModel.filterPublisher
            .combineLatest(viewModel.loadFailedPublisher)

        return grid.combineLatest(query)
            .map { grid, query in
                DataModel(isLoading: grid.0,
                          characters: grid.1,
                          pagination: grid.2,
                          filter: query.0,
                          loadFailed: query.1)
            }
            .eraseToAnyPublisher()
    }

    func mapToRenderModel(_ data: DataModel) -> CharactersGridRenderModel {
        guard !data.isLoading else {
            return .hidden
        }

        // `nil` is "no page has ever landed", which is not the same as "zero
        // results" and must not draw an empty state.
        guard let characters = data.characters else {
            return .hidden
        }

        guard !characters.isEmpty else {
            return data.loadFailed
                ? .empty(.failed)
                : .empty(.noMatches(summary: data.filter.summary,
                                    canClearFilters: data.filter.hasActiveFields))
        }

        return .visible(characters: characters,
                        footer: footer(for: data.pagination),
                        highlight: data.filter.name)
    }

    private func footer(for state: CharactersPaginationState) -> CharactersSectionFooter {
        switch state {
        case .idle: .loadMore
        case .loading: .loading
        case .failed: .retry
        case .end: .none
        }
    }
}
