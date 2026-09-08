//
//  CharacterDetailEpisodesSectionMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Core
import Foundation

enum CharacterDetailEpisodesRenderModel: Equatable {
    case hidden
    /// Distinguishes "no episodes" from a failed render, since this section cannot fail.
    case empty
    case visible(episodes: [CharacterDetailEpisodeModel])
}

@MainActor
final class CharacterDetailEpisodesSectionMapper: SectionMapperContract {
    typealias ViewModel = CharacterDetailEpisodesSectionViewModelContract
    typealias RenderModel = CharacterDetailEpisodesRenderModel

    struct DataModel {
        let isLoading: Bool
        let detail: CharacterDetailModel?
    }

    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    func dataPublisher(_ viewModel: ViewModel) -> AnyPublisher<DataModel, Never> {
        viewModel.loadingPublisher
            .combineLatest(viewModel.detailPublisher)
            .map { DataModel(isLoading: $0, detail: $1) }
            .eraseToAnyPublisher()
    }

    func mapToRenderModel(_ data: DataModel) -> CharacterDetailEpisodesRenderModel {
        guard !data.isLoading, let detail = data.detail else {
            return .hidden
        }

        // nil is "not asked yet"; an empty array is "asked, and there are none".
        guard !detail.episodes.isEmpty else {
            return .empty
        }

        return .visible(episodes: detail.episodes)
    }
}
