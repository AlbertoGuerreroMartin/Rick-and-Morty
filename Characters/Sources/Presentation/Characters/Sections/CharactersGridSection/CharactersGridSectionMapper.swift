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
    case visible(characters: [CharacterModel], footer: CharactersSectionFooter, highlight: String?)
    case empty(CharactersSectionEmptyReason)
}

protocol CharactersGridSectionMapperContract: SectionMapperContract {}

/// Mirrors the list mapper's rules so toggling layouts never disagrees on state.
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

    /// Two nested `combineLatest`s: Combine's `combineLatest` caps at four publishers.
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
