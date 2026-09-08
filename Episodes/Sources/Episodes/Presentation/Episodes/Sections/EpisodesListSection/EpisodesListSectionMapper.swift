//
//  EpisodesListSectionMapper.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Core
import Foundation

enum EpisodesListRenderModel: Equatable {
    case hidden
    case visible(seasons: [EpisodesSeasonRenderModel])
    case empty(EpisodesSectionEmptyReason)
}

/// Title baked in here so the copy is asserted by the mapper's tests, not only in a screenshot.
struct EpisodesSeasonRenderModel: Equatable, Identifiable {
    let season: Int
    let title: String
    let episodes: [EpisodeModel]

    var id: Int { season }
}

protocol EpisodesListSectionMapperContract: SectionMapperContract {}

/// Search is applied here, not the view model, so filtering/grouping/ordering stay one pure pass.
@MainActor
final class EpisodesListSectionMapper: EpisodesListSectionMapperContract {
    typealias ViewModel = EpisodesListSectionViewModelContract
    typealias RenderModel = EpisodesListRenderModel

    struct DataModel {
        let isLoading: Bool
        let episodes: [EpisodeModel]?
        let searchQuery: EpisodesSearchQuery
        let loadFailed: Bool
    }

    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    /// Four publishers, Combine's `combineLatest` limit.
    func dataPublisher(_ viewModel: ViewModel) -> AnyPublisher<DataModel, Never> {
        viewModel.loadingPublisher
            .combineLatest(viewModel.episodesPublisher,
                           viewModel.searchQueryPublisher,
                           viewModel.loadFailedPublisher)
            .map { isLoading, episodes, searchQuery, loadFailed in
                DataModel(isLoading: isLoading,
                          episodes: episodes,
                          searchQuery: searchQuery,
                          loadFailed: loadFailed)
            }
            .eraseToAnyPublisher()
    }

    func mapToRenderModel(_ data: DataModel) -> EpisodesListRenderModel {
        guard !data.isLoading else {
            return .hidden
        }

        guard let episodes = data.episodes else {
            return .hidden
        }

        guard !episodes.isEmpty else {
            return data.loadFailed ? .empty(.failed) : .empty(.noMatches(query: nil))
        }

        let matches = episodes.filter { data.searchQuery.matches($0) }

        guard !matches.isEmpty else {
            return .empty(.noMatches(query: data.searchQuery.text))
        }

        return .visible(seasons: seasons(from: matches))
    }

    /// `code` then `id` break ties between episodes sharing a number.
    private func seasons(from episodes: [EpisodeModel]) -> [EpisodesSeasonRenderModel] {
        Dictionary(grouping: episodes, by: \.season)
            .sorted { $0.key < $1.key }
            .map { season, episodes in
                EpisodesSeasonRenderModel(season: season,
                                          title: String(localized: "Season \(season)", bundle: .module),
                                          episodes: episodes.sorted(by: Self.isOrderedBefore))
            }
    }

    private static func isOrderedBefore(_ lhs: EpisodeModel, _ rhs: EpisodeModel) -> Bool {
        (lhs.number, lhs.code, lhs.id) < (rhs.number, rhs.code, rhs.id)
    }
}
