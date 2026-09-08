//
//  CharactersListSectionMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine
import Core
import Foundation

enum CharactersListRenderModel: Equatable {
    case hidden
    /// `highlight` is `nil` when there is no search text.
    case visible(characters: [CharacterModel], footer: CharactersSectionFooter, highlight: String?)
    case empty(CharactersSectionEmptyReason)
}

@MainActor
final class CharactersListSectionMapper: SectionMapperContract {
    typealias ViewModel = CharactersListSectionViewModelContract
    typealias RenderModel = CharactersListRenderModel

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

    /// Nested `combineLatest`s: Combine's operator tops out at four streams for five publishers.
    func dataPublisher(_ viewModel: ViewModel) -> AnyPublisher<DataModel, Never> {
        let list = viewModel.loadingPublisher
            .combineLatest(viewModel.charactersPublisher, viewModel.paginationPublisher)
        let query = viewModel.filterPublisher
            .combineLatest(viewModel.loadFailedPublisher)

        return list.combineLatest(query)
            .map { list, query in
                DataModel(isLoading: list.0,
                          characters: list.1,
                          pagination: list.2,
                          filter: query.0,
                          loadFailed: query.1)
            }
            .eraseToAnyPublisher()
    }

    func mapToRenderModel(_ data: DataModel) -> CharactersListRenderModel {
        guard !data.isLoading else {
            return .hidden
        }

        // `nil` means no page has landed yet; not the same as zero results.
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
