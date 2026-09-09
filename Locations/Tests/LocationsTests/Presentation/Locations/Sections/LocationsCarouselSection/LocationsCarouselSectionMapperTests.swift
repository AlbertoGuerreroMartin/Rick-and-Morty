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

@Suite("LocationsCarouselSectionMapper")
@MainActor
struct LocationsCarouselSectionMapperTests {

    @Test("loading hides the carousel")
    func loadingHides() {
        #expect(map(.make(isLoading: true, locations: [.make()])) == .hidden)
    }

    @Test("loading beats a previous failure")
    func loadingBeatsFailure() {
        #expect(map(.make(isLoading: true, locations: [], loadFailed: true)) == .hidden)
    }

    @Test("a nil list stays hidden rather than empty")
    func nilStaysHidden() {
        #expect(map(.make(locations: nil)) == .hidden)
    }

    @Test("an empty list after a failure offers a retry")
    func emptyAfterAFailure() {
        #expect(map(.make(locations: [], loadFailed: true)) == .empty(.failed))
    }

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

    @Test("the end of the list draws nothing")
    func endIsNone() throws {
        #expect(try footer(map(.make(locations: [.make()], pagination: .end))) == .none)
    }

    // MARK: - The publisher

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
    static var crowd: [LocationResidentModel] {
        (1...6).map { index in
            LocationResidentModel(id: "\(index)",
                                  name: "Resident \(index)",
                                  status: LocationResidentStatus.allCases[index % LocationResidentStatus.allCases.count],
                                  species: "Human",
                                  image: URL(string: "https://example.com/\(index).jpeg")!)
        }
    }
}
