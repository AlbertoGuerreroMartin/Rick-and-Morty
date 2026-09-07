//
//  CharactersListSectionMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine
import Core
import Foundation

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

/// Why there is nothing to draw.
///
/// The two cases are told apart deliberately: "your search matched nothing" and
/// "we could not ask" look identical in an empty list, but one is answered by
/// widening the filter and the other by tapping Retry. Collapsing them would
/// offer the user the wrong button.
enum CharactersListEmptyReason: Equatable {
    /// The server answered, with nothing. `summary` is the filter in words, for
    /// copy that says *what* found nothing; `canClearFilters` is false when
    /// there is no filter to clear and the button would be a dead end.
    case noMatches(summary: String?, canClearFilters: Bool)
    case failed
}

enum CharactersListRenderModel: Equatable {
    case hidden
    /// `highlight` is the substring to emphasise in each row's name, or `nil`
    /// when there is no search text.
    case visible(characters: [CharacterModel], footer: CharactersListFooter, highlight: String?)
    case empty(CharactersListEmptyReason)
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
        let filter: CharactersFilter
        let loadFailed: Bool
    }

    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    /// Five publishers through two `combineLatest`s: Combine's operator tops out
    /// at four streams, so the pair is nested rather than the view model growing
    /// a single pre-combined "state" publisher — which would defeat the point of
    /// per-property publishers, since every section would then wake for every
    /// change.
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

    /// The order of these rules *is* the screen's behaviour, so they are written
    /// as one straight line of early returns rather than a nest of conditions.
    func mapToRenderModel(_ data: DataModel) -> CharactersListRenderModel {
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

    private func footer(for state: CharactersPaginationState) -> CharactersListFooter {
        switch state {
        case .idle: .loadMore
        case .loading: .loading
        case .failed: .retry
        case .end: .none
        }
    }
}
