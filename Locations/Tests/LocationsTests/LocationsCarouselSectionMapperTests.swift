//
//  LocationsCarouselSectionMapperTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine
import Foundation
import Testing
@testable import Locations

/// The order of the mapper's rules *is* the screen's behaviour, so these run
/// down them one at a time: loading beats everything, `nil` is not empty, empty
/// is one of two states, and only then are there circles.
@Suite("LocationsCarouselSectionMapper")
@MainActor
struct LocationsCarouselSectionMapperTests {

    @Test("loading hides the carousel")
    func loadingHides() {
        #expect(map(.make(isLoading: true, locations: [.make()])) == .hidden)
    }

    /// Loading wins even over a failure: a retry raises the spinner before it
    /// clears the flag, and an empty state that stayed for the length of the new
    /// request would look like the button had done nothing.
    @Test("loading beats a previous failure")
    func loadingBeatsFailure() {
        #expect(map(.make(isLoading: true, locations: [], loadFailed: true)) == .hidden)
    }

    /// `nil` is "no page has ever landed", which is not the same as "zero
    /// locations" and must not draw an empty state.
    @Test("a nil list stays hidden rather than empty")
    func nilStaysHidden() {
        #expect(map(.make(locations: nil)) == .hidden)
    }

    @Test("an empty list after a failure offers a retry")
    func emptyAfterAFailure() {
        #expect(map(.make(locations: [], loadFailed: true)) == .empty(.failed))
    }

    /// The API answered, and answered with nothing. There is no Retry here
    /// because there is nothing to retry.
    @Test("an empty list without a failure says there are no locations")
    func emptyWithoutAFailure() {
        #expect(map(.make(locations: [])) == .empty(.noLocations))
    }

    // MARK: - Items

    @Test("each location becomes a circle carrying its name")
    func itemsCarryTheirCopy() throws {
        let render = map(.make(locations: [
            .make(id: "1", name: "Earth (C-137)", type: "Planet"),
            .make(id: "2", name: "Abadango", type: "Cluster")
        ]))

        #expect(try items(render) == [
            LocationsCarouselItemRenderModel(id: "1", title: "Earth (C-137)"),
            LocationsCarouselItemRenderModel(id: "2", title: "Abadango")
        ])
    }

    /// A circle has room for one thing, and the card below is already describing
    /// the focused location in full — so the type and the dimension stop here.
    @Test("nothing but the name reaches the circle")
    func onlyTheNameReachesTheItem() throws {
        let render = map(.make(locations: [
            .make(id: "1", name: "Earth", type: "Planet", dimension: "Dimension C-137")
        ]))

        #expect(try items(render).first?.title == "Earth")
    }

    @Test("the locations keep their arrival order")
    func itemsKeepTheirOrder() throws {
        let render = map(.make(locations: [
            .make(id: "3", name: "Third"), .make(id: "1", name: "First"), .make(id: "2", name: "Second")
        ]))

        #expect(try items(render).map(\.id) == ["3", "1", "2"])
    }

    // MARK: - Selection

    @Test("the selected id is passed through untouched")
    func selectedIdIsPassedThrough() throws {
        let render = map(.make(locations: [.make(id: "1"), .make(id: "2")], selectedId: "2"))

        #expect(try selectedId(render) == "2")
    }

    /// The carousel is the one place that can be showing something before the
    /// selection has been decided — the first frame after a page lands — so a
    /// `nil` here has to survive rather than be invented.
    @Test("no selection is passed through as nil")
    func noSelectionIsNil() throws {
        let render = map(.make(locations: [.make(id: "1")], selectedId: nil))

        #expect(try selectedId(render) == nil)
    }

    // MARK: - Footer

    @Test("idle offers to load more")
    func idleIsLoadMore() throws {
        #expect(try footer(map(.make(locations: [.make()], pagination: .idle(nextPage: 2)))) == .loadMore)
    }

    @Test("loading draws the spinner")
    func loadingIsLoading() throws {
        #expect(try footer(map(.make(locations: [.make()], pagination: .loading))) == .loading)
    }

    @Test("a failed page draws the retry")
    func failedIsRetry() throws {
        #expect(try footer(map(.make(locations: [.make()], pagination: .failed(nextPage: 4)))) == .retry)
    }

    /// The page number rides inside the state and is deliberately *not* in the
    /// footer: the view has no use for it, and giving it one would be a second
    /// place for "which page is next" to live.
    @Test("the end of the list draws nothing")
    func endIsNone() throws {
        #expect(try footer(map(.make(locations: [.make()], pagination: .end))) == .none)
    }

    // MARK: - The publisher

    /// The rules above are asserted on `mapToRenderModel` directly; this is the
    /// other half — that the five streams are actually wired, which the nested
    /// `combineLatest` is easy to get subtly wrong.
    @Test("the data publisher combines all five streams")
    func dataPublisherCombinesEverything() async throws {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = [.make(id: "1", name: "Earth", type: "Planet")]
        viewModel.pagination = .idle(nextPage: 2)
        viewModel.selectedId = "1"
        let mapper = LocationsCarouselSectionMapper(viewModel: viewModel)

        var received: LocationsCarouselSectionMapper.DataModel?
        let cancellable = mapper.dataPublisher(viewModel).sink { received = $0 }
        defer { cancellable.cancel() }

        let data = try #require(received)
        #expect(data.isLoading == false)
        #expect(data.locations?.map(\.id) == ["1"])
        #expect(data.pagination == .idle(nextPage: 2))
        #expect(data.loadFailed == false)
        #expect(data.selectedId == "1")
    }

    // MARK: - Helpers

    private func map(_ data: LocationsCarouselSectionMapper.DataModel) -> LocationsCarouselRenderModel {
        LocationsCarouselSectionMapper(viewModel: StubLocationsCarouselViewModel()).mapToRenderModel(data)
    }

    private func items(_ render: LocationsCarouselRenderModel) throws -> [LocationsCarouselItemRenderModel] {
        guard case .visible(let items, _, _) = render else {
            throw MapperExpectationError.notVisible
        }
        return items
    }

    private func selectedId(_ render: LocationsCarouselRenderModel) throws -> String? {
        guard case .visible(_, let selectedId, _) = render else {
            throw MapperExpectationError.notVisible
        }
        return selectedId
    }

    private func footer(_ render: LocationsCarouselRenderModel) throws -> LocationsSectionFooter {
        guard case .visible(_, _, let footer) = render else {
            throw MapperExpectationError.notVisible
        }
        return footer
    }
}

enum MapperExpectationError: Error {
    case notVisible
}

extension LocationsCarouselSectionMapper.DataModel {
    /// Named defaults for "nothing special is going on", so each test states only
    /// the one thing it is about.
    static func make(isLoading: Bool = false,
                     locations: [LocationModel]? = [],
                     pagination: LocationsPaginationState = .end,
                     loadFailed: Bool = false,
                     selectedId: String? = nil) -> Self {
        Self(isLoading: isLoading,
             locations: locations,
             pagination: pagination,
             loadFailed: loadFailed,
             selectedId: selectedId)
    }
}

// MARK: - Fixtures

extension LocationModel {
    static func make(id: String = "1",
                     name: String = "Earth (C-137)",
                     type: String? = "Planet",
                     dimension: String? = "Dimension C-137",
                     residents: [LocationResidentModel] = []) -> LocationModel {
        LocationModel(id: id, name: name, type: type, dimension: dimension, residents: residents)
    }
}

extension Array where Element == LocationResidentModel {
    /// A handful of avatars, so the strip has something lazy to build.
    static var crowd: [LocationResidentModel] {
        (1...6).map { index in
            LocationResidentModel(id: "\(index)",
                                  name: "Resident \(index)",
                                  image: URL(string: "https://example.com/\(index).jpeg")!)
        }
    }
}

/// The mapper needs a view model to hold, and the publisher test needs it to
/// actually emit. Everything is a plain stored property replayed through a
/// `Just`, so a test sets a value and gets one deterministic emission.
@MainActor
final class StubLocationsCarouselViewModel: LocationsCarouselSectionViewModelContract {
    var isLoading = false
    var locations: [LocationModel]?
    var pagination: LocationsPaginationState = .end
    var loadFailed = false
    var selectedId: String?
    private(set) var retryCallCount = 0
    private(set) var loadNextPageCallCount = 0
    private(set) var selectedIds: [String] = []

    var loadingPublisher: AnyPublisher<Bool, Never> { Just(isLoading).eraseToAnyPublisher() }
    var locationsPublisher: AnyPublisher<[LocationModel]?, Never> { Just(locations).eraseToAnyPublisher() }
    var paginationPublisher: AnyPublisher<LocationsPaginationState, Never> {
        Just(pagination).eraseToAnyPublisher()
    }
    var loadFailedPublisher: AnyPublisher<Bool, Never> { Just(loadFailed).eraseToAnyPublisher() }
    var selectedLocationIdPublisher: AnyPublisher<String?, Never> {
        Just(selectedId).eraseToAnyPublisher()
    }

    func loadNextPage() async {
        loadNextPageCallCount += 1
    }

    func retryLoad() {
        retryCallCount += 1
    }

    func selectLocation(id: String) {
        selectedIds.append(id)
        selectedId = id
    }
}
