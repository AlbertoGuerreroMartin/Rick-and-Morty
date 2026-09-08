//
//  CharacterDetailHeaderSectionMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Core
import Foundation

/// The four fields the header draws, not the full `CharacterDetailModel`, so a test can assert
/// on the header without constructing a character's origin, dimension and filmography too.
struct CharacterDetailHeaderRenderModel: Equatable {
    let name: String
    let image: URL
    let status: CharacterStatus
    let species: String
}

enum CharacterDetailHeaderRenderState: Equatable {
    /// See the section view for why this takes the full square rather than an empty frame.
    case hidden
    case failed
    case visible(CharacterDetailHeaderRenderModel)
}

protocol CharacterDetailHeaderSectionMapperContract: SectionMapperContract {}

@MainActor
final class CharacterDetailHeaderSectionMapper: CharacterDetailHeaderSectionMapperContract {
    typealias ViewModel = CharacterDetailHeaderSectionViewModelContract
    typealias RenderModel = CharacterDetailHeaderRenderState

    struct DataModel {
        let isLoading: Bool
        let detail: CharacterDetailModel?
        let loadFailed: Bool
    }

    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    func dataPublisher(_ viewModel: ViewModel) -> AnyPublisher<DataModel, Never> {
        viewModel.loadingPublisher
            .combineLatest(viewModel.detailPublisher, viewModel.loadFailedPublisher)
            .map { DataModel(isLoading: $0, detail: $1, loadFailed: $2) }
            .eraseToAnyPublisher()
    }

    /// Loading beats failure: a retry raises the spinner before clearing the flag, so checking
    /// failure first would show the previous error for the length of the new request.
    func mapToRenderModel(_ data: DataModel) -> CharacterDetailHeaderRenderState {
        guard !data.isLoading else {
            return .hidden
        }

        guard !data.loadFailed else {
            return .failed
        }

        // `nil` means nothing has landed yet, before `.task` has run — a spinner, not an error.
        guard let detail = data.detail else {
            return .hidden
        }

        return .visible(CharacterDetailHeaderRenderModel(name: detail.name,
                                                         image: detail.image,
                                                         status: detail.status,
                                                         species: detail.species))
    }
}
