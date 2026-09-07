//
//  EpisodesListSectionMapperTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Foundation
import Testing
@testable import Episodes

/// The mapper is where "what the view model knows" becomes "what the screen
/// shows", and on this screen it is also where the search, the grouping and the
/// ordering happen. The *order* of its rules is the screen's behaviour — a
/// spinner beating an empty state, a `nil` list never being mistaken for a
/// zero-length one — so each rule gets a test.
@Suite("EpisodesListSectionMapper")
@MainActor
struct EpisodesListSectionMapperTests {

    // MARK: - The rules, in order

    @Test("loading hides everything")
    func loadingHidesTheList() {
        #expect(map(.make(isLoading: true, episodes: [.make()])) == .hidden)
    }

    @Test("no load has ever landed hides the list rather than emptying it")
    func nilEpisodesIsHiddenNotEmpty() {
        #expect(map(.make(episodes: nil)) == .hidden)
    }

    /// Nothing was loaded, so the query is *not* named: it matched nothing
    /// because there was nothing to match, and blaming the user's text would be
    /// a lie.
    @Test("an empty catalogue is no results, with nothing to blame")
    func emptyCatalogueHasNoQuery() {
        #expect(map(.make(episodes: [])) == .empty(.noMatches(query: nil)))
        #expect(map(.make(episodes: [], searchQuery: EpisodesSearchQuery(text: "pilot")))
                == .empty(.noMatches(query: nil)))
    }

    @Test("a failed load offers a retry, not a change-your-search")
    func failedLoadIsItsOwnEmptyState() {
        #expect(map(.make(episodes: [], loadFailed: true)) == .empty(.failed))
    }

    /// The catalogue is on the device, so the search is the only reason nothing
    /// is showing — and saying so is what turns a blank screen into something
    /// the user can act on.
    @Test("a search that matches nothing quotes the search back")
    func noMatchesNamesTheQuery() {
        let data = DataModel.make(episodes: [.make(name: "Pilot")],
                                  searchQuery: EpisodesSearchQuery(text: "squanch"))

        #expect(map(data) == .empty(.noMatches(query: "squanch")))
    }

    @Test("matching rows survive the search and the rest are dropped")
    func theSearchFiltersTheRows() throws {
        let data = DataModel.make(episodes: [.make(name: "Pilot", season: 1, number: 1),
                                             .make(name: "Lawnmower Dog", season: 1, number: 2)],
                                  searchQuery: EpisodesSearchQuery(text: "lawnmower"))

        let seasons = try #require(visibleSeasons(map(data)))
        #expect(seasons.flatMap { $0.episodes.map(\.name) } == ["Lawnmower Dog"])
    }

    // MARK: - Grouping and ordering

    @Test("episodes are grouped by season, ascending")
    func seasonsAreGroupedAscending() throws {
        let data = DataModel.make(episodes: [.make(season: 3, number: 1),
                                             .make(season: 1, number: 1),
                                             .make(season: 2, number: 1)])

        let seasons = try #require(visibleSeasons(map(data)))
        #expect(seasons.map(\.season) == [1, 2, 3])
        #expect(seasons.map(\.id) == [1, 2, 3])
    }

    /// The input arrives in whatever order the server paginated it in, and the
    /// search then removes rows from the middle of that order. Sorting has to be
    /// explicit or the grouping reads as arbitrary.
    @Test("episodes inside a season are ordered by number, whatever the input order")
    func episodesAreOrderedWithinASeason() throws {
        let data = DataModel.make(episodes: [.make(season: 1, number: 11),
                                             .make(season: 1, number: 2),
                                             .make(season: 1, number: 1)])

        let seasons = try #require(visibleSeasons(map(data)))
        #expect(seasons.first?.episodes.map(\.number) == [1, 2, 11])
    }

    /// Two episodes claiming the same number is malformed data, not a crash —
    /// but the order still has to be stable, because a list that reshuffled
    /// between two keystrokes would look like a bug regardless of the cause.
    @Test("a tie on number is broken by code and then id")
    func tiesAreBrokenDeterministically() throws {
        let first = EpisodeModel(id: "a", name: "A", airDate: "2013", code: "S01E01",
                                 season: 1, number: 1, created: nil, characters: [])
        let second = EpisodeModel(id: "b", name: "B", airDate: "2013", code: "S01E01",
                                  season: 1, number: 1, created: nil, characters: [])

        let ascending = try #require(visibleSeasons(map(.make(episodes: [first, second]))))
        let descending = try #require(visibleSeasons(map(.make(episodes: [second, first]))))

        #expect(ascending.first?.episodes.map(\.id) == ["a", "b"])
        #expect(descending.first?.episodes.map(\.id) == ["a", "b"])
    }

    @Test("a season whose episodes all fail the search does not appear")
    func emptySeasonsAreDropped() throws {
        let data = DataModel.make(episodes: [.make(name: "Pilot", season: 1, number: 1),
                                             .make(name: "Rickshank", season: 3, number: 1)],
                                  searchQuery: EpisodesSearchQuery(text: "rickshank"))

        let seasons = try #require(visibleSeasons(map(data)))
        #expect(seasons.map(\.season) == [3])
    }

    @Test("each season carries its own title")
    func seasonsCarryTheirTitle() throws {
        let data = DataModel.make(episodes: [.make(season: 1, number: 1),
                                             .make(season: 12, number: 1)])

        let seasons = try #require(visibleSeasons(map(data)))
        #expect(seasons.map(\.title) == ["Season 1", "Season 12"])
    }

    // MARK: - The publisher

    /// The four streams have to actually reach `mapToRenderModel`, and a
    /// `combineLatest` that dropped one would only show up as a screen that
    /// never updates.
    @Test("the data publisher combines all four view model streams")
    func dataPublisherCombinesEveryStream() async throws {
        let viewModel = StubEpisodesListViewModel()
        viewModel.episodes = [.make(name: "Pilot", season: 1, number: 1),
                              .make(name: "Lawnmower Dog", season: 1, number: 2)]
        viewModel.searchQuery = EpisodesSearchQuery(text: "pilot")
        let mapper = EpisodesListSectionMapper(viewModel: viewModel)

        var cancellables: Set<AnyCancellable> = []
        let render: EpisodesListRenderModel = await withCheckedContinuation { continuation in
            mapper.renderModelPublisher()
                .first()
                .sink { continuation.resume(returning: $0) }
                .store(in: &cancellables)
        }

        let seasons = try #require(visibleSeasons(render))
        #expect(seasons.flatMap { $0.episodes.map(\.name) } == ["Pilot"])
    }

    // MARK: - Helpers

    private typealias DataModel = EpisodesListSectionMapper.DataModel

    private func map(_ data: DataModel) -> EpisodesListRenderModel {
        EpisodesListSectionMapper(viewModel: StubEpisodesListViewModel()).mapToRenderModel(data)
    }

    private func visibleSeasons(_ render: EpisodesListRenderModel) -> [EpisodesSeasonRenderModel]? {
        guard case .visible(let seasons) = render else { return nil }
        return seasons
    }
}

private extension EpisodesListSectionMapper.DataModel {
    /// Named defaults for "nothing special is going on", so each test states
    /// only the one thing it is about.
    static func make(isLoading: Bool = false,
                     episodes: [EpisodeModel]? = [],
                     searchQuery: EpisodesSearchQuery = .empty,
                     loadFailed: Bool = false) -> Self {
        Self(isLoading: isLoading,
             episodes: episodes,
             searchQuery: searchQuery,
             loadFailed: loadFailed)
    }
}

// MARK: - Fixtures

extension EpisodeModel {
    /// The code is derived from the season and the number so a fixture cannot
    /// describe an episode whose code disagrees with its grouping.
    static func make(id: String? = nil,
                     name: String = "Pilot",
                     airDate: String = "December 2, 2013",
                     season: Int = 1,
                     number: Int = 1,
                     created: Date? = nil,
                     characters: [EpisodeCharacterModel] = []) -> EpisodeModel {
        let code = String(format: "S%02dE%02d", season, number)
        return EpisodeModel(id: id ?? "\(code)-\(name)",
                            name: name,
                            airDate: airDate,
                            code: code,
                            season: season,
                            number: number,
                            created: created,
                            characters: characters)
    }
}

/// The mapper needs a view model to hold, and the publisher test needs it to
/// actually emit. Everything is a plain stored property replayed through a
/// `Just`, so a test sets a value and gets one deterministic emission.
@MainActor
final class StubEpisodesListViewModel: EpisodesListSectionViewModelContract {
    var isLoading = false
    var episodes: [EpisodeModel]?
    var searchQuery: EpisodesSearchQuery = .empty
    var loadFailed = false
    private(set) var retryCallCount = 0

    var loadingPublisher: AnyPublisher<Bool, Never> { Just(isLoading).eraseToAnyPublisher() }
    var episodesPublisher: AnyPublisher<[EpisodeModel]?, Never> { Just(episodes).eraseToAnyPublisher() }
    var searchQueryPublisher: AnyPublisher<EpisodesSearchQuery, Never> {
        Just(searchQuery).eraseToAnyPublisher()
    }
    var loadFailedPublisher: AnyPublisher<Bool, Never> { Just(loadFailed).eraseToAnyPublisher() }

    func retryLoad() {
        retryCallCount += 1
    }
}
