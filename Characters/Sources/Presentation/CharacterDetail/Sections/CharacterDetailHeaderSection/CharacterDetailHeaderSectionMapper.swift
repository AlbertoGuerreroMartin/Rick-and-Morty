//
//  CharacterDetailHeaderSectionMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Core
import Foundation

/// The four things the header draws over the picture.
///
/// A render model of its own rather than the `CharacterDetailModel`: the header
/// shows four of its eleven fields, and baking exactly those four is what lets a
/// test say "the header shows the species" without constructing a character that
/// also has an origin, a dimension and a filmography.
struct CharacterDetailHeaderRenderModel: Equatable {
    let name: String
    let image: URL
    let status: CharacterStatus
    let species: String
}

enum CharacterDetailHeaderRenderState: Equatable {
    /// Nothing has landed yet. The header still takes its full square, with the
    /// spinner in it — see the section view for why it is not an empty frame.
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

    /// The order of these rules *is* the screen's behaviour, so they are written
    /// as one straight line of early returns rather than a nest of conditions.
    ///
    /// Loading beats failure deliberately: a retry raises the spinner before it
    /// clears the flag, and a header that showed the previous error for the
    /// length of the new request would look like the retry had done nothing.
    func mapToRenderModel(_ data: DataModel) -> CharacterDetailHeaderRenderState {
        guard !data.isLoading else {
            return .hidden
        }

        guard !data.loadFailed else {
            return .failed
        }

        // `nil` is "nothing has landed", which on this screen is the state
        // before the `.task` has even run. It is a spinner, not an error.
        guard let detail = data.detail else {
            return .hidden
        }

        return .visible(CharacterDetailHeaderRenderModel(name: detail.name,
                                                         image: detail.image,
                                                         status: detail.status,
                                                         species: detail.species))
    }
}
