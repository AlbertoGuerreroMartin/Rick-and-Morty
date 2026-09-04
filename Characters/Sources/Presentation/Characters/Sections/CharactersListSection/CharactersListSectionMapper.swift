//
//  CharactersListSectionMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine
import Core

/// What the last row of the list is, once the rows above it are drawn.
///
/// The view never sees `CharactersPaginationState`: the difference between
/// `.idle` and `.loading` is a trigger detail, and both draw the same spinner.
enum CharactersListFooter: Equatable {
    /// Nothing loading yet, and there is a page waiting — the row's `.task` is
    /// what asks for it.
    case loadMore
    case loading
    case retry
    case none
}

enum CharactersListRenderModel {
    case visible(characters: [CharacterModel], footer: CharactersListFooter)
    case hidden
}

protocol CharactersListSectionMapperContract: SectionMapperContract {}

@MainActor
final class CharactersListSectionMapper: CharactersListSectionMapperContract {
    typealias ViewModel = CharactersListSectionViewModelContract
    typealias RenderModel = CharactersListRenderModel

    struct DataModel {
        let isLoading: Bool
        let characters: [CharacterModel]?
        let pagination: CharactersPaginationState
    }

    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    func dataPublisher(_ viewModel: ViewModel) -> AnyPublisher<DataModel, Never> {
        viewModel.loadingPublisher
            .combineLatest(viewModel.charactersPublisher, viewModel.paginationPublisher)
            .map { DataModel(isLoading: $0, characters: $1, pagination: $2) }
            .eraseToAnyPublisher()
    }

    func mapToRenderModel(_ data: DataModel) -> CharactersListRenderModel {
        guard !data.isLoading else {
            return .hidden
        }

        return .visible(characters: data.characters ?? [], footer: footer(for: data.pagination))
    }

    private func footer(for state: CharactersPaginationState) -> CharactersListFooter {
        switch state {
        case .idle: .loadMore
        case .loading: .loading
        case .failed: .retry
        case .end: .none
        }
    }
}
