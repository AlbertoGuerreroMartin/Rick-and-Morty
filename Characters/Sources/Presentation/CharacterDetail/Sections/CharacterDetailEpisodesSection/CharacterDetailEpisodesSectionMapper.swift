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
    /// Nothing has landed. The header is drawing the spinner, so this section
    /// draws nothing at all rather than a second one.
    case hidden
    /// The character loaded and appears in no episodes. Rare, and worth saying
    /// out loud: an absent section would be indistinguishable from a section
    /// that failed to render, and this one cannot fail.
    case empty
    case visible(episodes: [CharacterDetailEpisodeModel])
}

protocol CharacterDetailEpisodesSectionMapperContract: SectionMapperContract {}

/// The character's filmography, in the API's own order.
///
/// There is deliberately no grouping, no sorting and no search here, all of
/// which the Episodes screen does. The reason is the input: this is the list of
/// episodes *one character appears in*, already in broadcast order, and it is
/// tens of rows rather than the whole catalogue. Grouping it by season would
/// turn a short readable list into a set of one- and two-row groups, and sorting
/// an answer that is already sorted is a chance to get it wrong.
@MainActor
final class CharacterDetailEpisodesSectionMapper: CharacterDetailEpisodesSectionMapperContract {
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

        // The distinction the whole enum exists for: `nil` is "we have not
        // asked yet" and an empty array is "we asked, and there are none".
        guard !detail.episodes.isEmpty else {
            return .empty
        }

        return .visible(episodes: detail.episodes)
    }
}
