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

/// One `Section` of the list: a header and the episodes under it.
///
/// The title is baked in rather than derived in the view, so the copy is
/// asserted by the mapper's tests instead of only being visible in a screenshot.
struct EpisodesSeasonRenderModel: Equatable, Identifiable {
    let season: Int
    /// e.g. `Season 1`.
    let title: String
    let episodes: [EpisodeModel]

    /// The season number is already unique within a render model — the grouping
    /// below guarantees it — so it is the identity, and `ForEach` needs nothing
    /// else.
    var id: Int { season }
}

protocol EpisodesListSectionMapperContract: SectionMapperContract {}

/// Turns "everything that was loaded" plus "what the user typed" into the
/// sections the screen draws.
///
/// **The search is applied here, not in the view model.** The view model
/// publishes the whole catalogue and the query as two independent facts; this is
/// the one place that combines them. That keeps a single source of truth — there
/// is no second, filtered list on the view model that could drift out of step
/// with the first — and it puts the filtering next to the grouping and the
/// ordering, which are the other two things that have to happen to the same rows
/// in the same pass. It also makes the whole behaviour a pure function of a data
/// model, so every rule below is testable without a network, a cache or a view.
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

    /// Four publishers through one `combineLatest`, which is exactly Combine's
    /// limit — the view model keeps a publisher per property rather than one
    /// pre-combined "state", so a section only wakes for the properties it
    /// actually reads.
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

    /// The order of these rules *is* the screen's behaviour, so they are written
    /// as one straight line of early returns rather than a nest of conditions.
    func mapToRenderModel(_ data: DataModel) -> EpisodesListRenderModel {
        guard !data.isLoading else {
            return .hidden
        }

        // `nil` is "no load has ever landed", which is not the same as "zero
        // episodes" and must not draw an empty state.
        guard let episodes = data.episodes else {
            return .hidden
        }

        // Nothing was loaded at all. Whether that is a failure or a genuinely
        // empty catalogue decides which button the user gets, and only the load
        // knows — so the query is *not* named here: it matched nothing because
        // there was nothing to match, and blaming the user's text would be a
        // lie.
        guard !episodes.isEmpty else {
            return data.loadFailed ? .empty(.failed) : .empty(.noMatches(query: nil))
        }

        let matches = episodes.filter { data.searchQuery.matches($0) }

        // Here the query *is* named: the catalogue is on the device, so the
        // search is the only reason nothing is showing, and saying so is what
        // turns a blank screen into something the user can act on.
        guard !matches.isEmpty else {
            return .empty(.noMatches(query: data.searchQuery.text))
        }

        return .visible(seasons: seasons(from: matches))
    }

    /// Groups by season, orders both levels, and drops nothing but empties.
    ///
    /// Ordering is explicit rather than inherited from the server's order, for
    /// two reasons: the search filters rows out of the middle of it, and a list
    /// grouped into sections has to be sorted *within* a section anyway or the
    /// grouping reads as arbitrary. `code` then `id` break a tie between two
    /// episodes claiming the same number, so the output is deterministic even
    /// against a malformed catalogue — a list whose order changed between two
    /// keystrokes would look like a bug regardless of the cause.
    ///
    /// A season with no matches simply does not appear: `Dictionary(grouping:)`
    /// never creates an empty group, so the "drop empty seasons" rule is
    /// structural rather than a filter that could be forgotten.
    private func seasons(from episodes: [EpisodeModel]) -> [EpisodesSeasonRenderModel] {
        Dictionary(grouping: episodes, by: \.season)
            .sorted { $0.key < $1.key }
            .map { season, episodes in
                EpisodesSeasonRenderModel(season: season,
                                          title: "Season \(season)",
                                          episodes: episodes.sorted(by: Self.isOrderedBefore))
            }
    }

    private static func isOrderedBefore(_ lhs: EpisodeModel, _ rhs: EpisodeModel) -> Bool {
        (lhs.number, lhs.code, lhs.id) < (rhs.number, rhs.code, rhs.id)
    }
}
