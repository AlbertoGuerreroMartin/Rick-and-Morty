//
//  LocationDetailSectionMapperTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine
import Foundation
import Testing
@testable import Locations

@Suite("LocationDetailSectionMapper")
@MainActor
struct LocationDetailSectionMapperTests {

    // MARK: - Hidden

    @Test("nothing loaded hides the card")
    func nilLocationsHides() {
        #expect(map(.make(locations: nil, selectedId: "1")) == .hidden)
    }

    @Test("nothing selected hides the card")
    func noSelectionHides() {
        #expect(map(.make(locations: [.make(id: "1")], selectedId: nil)) == .hidden)
    }

    @Test("a selected id that is not in the list hides the card")
    func unknownSelectionHides() {
        #expect(map(.make(locations: [.make(id: "1")], selectedId: "nowhere")) == .hidden)
    }

    @Test("an empty list hides the card")
    func emptyListHides() {
        #expect(map(.make(locations: [], selectedId: "1")) == .hidden)
    }

    // MARK: - Content

    @Test("the selected location's name is the title")
    func nameIsTheTitle() throws {
        let content = try content(map(.make(
            locations: [.make(id: "1", name: "Earth (C-137)"), .make(id: "2", name: "Abadango")],
            selectedId: "2"
        )))

        #expect(content.name == "Abadango")
    }

    @Test("both rows are drawn, label and value, in order")
    func bothRowsAreDrawn() throws {
        let content = try content(map(.make(
            locations: [.make(id: "1", type: "Planet", dimension: "Dimension C-137")],
            selectedId: "1"
        )))

        #expect(content.rows == [
            LocationDetailInfoRow(label: "Type", value: "Planet"),
            LocationDetailInfoRow(label: "Dimension", value: "Dimension C-137")
        ])
    }

    @Test("a location with no type draws only the dimension")
    func noTypeDrawsOneRow() throws {
        let content = try content(map(.make(
            locations: [.make(id: "1", type: nil, dimension: "unknown")],
            selectedId: "1"
        )))

        #expect(content.rows == [LocationDetailInfoRow(label: "Dimension", value: "unknown")])
    }

    @Test("a location with no dimension draws only the type")
    func noDimensionDrawsOneRow() throws {
        let content = try content(map(.make(
            locations: [.make(id: "1", type: "Space station", dimension: nil)],
            selectedId: "1"
        )))

        #expect(content.rows == [LocationDetailInfoRow(label: "Type", value: "Space station")])
    }

    @Test("a location with neither draws no rows at all")
    func neitherDrawsNothing() throws {
        let content = try content(map(.make(
            locations: [.make(id: "1", type: nil, dimension: nil)],
            selectedId: "1"
        )))

        #expect(content.rows.isEmpty)
    }

    @Test("the API's literal unknown is shown rather than dropped")
    func literalUnknownIsShown() throws {
        let content = try content(map(.make(
            locations: [.make(id: "1", type: "unknown", dimension: "unknown")],
            selectedId: "1"
        )))

        #expect(content.rows.map(\.value) == ["unknown", "unknown"])
    }

    @Test("the id is never a row")
    func idIsNeverARow() throws {
        let content = try content(map(.make(locations: [.make(id: "42")], selectedId: "42")))

        #expect(!content.rows.contains { $0.label == "ID" })
        #expect(!content.rows.contains { $0.value == "42" })
    }

    // MARK: - Residents

    @Test("the residents are passed through in order")
    func residentsArePassedThrough() throws {
        let content = try content(map(.make(
            locations: [.make(id: "1", residents: .crowd)],
            selectedId: "1"
        )))

        #expect(content.residents.map(\.id) == ["1", "2", "3", "4", "5", "6"])
    }

    @Test("the resident count is pluralized")
    func residentCountIsPluralized() throws {
        #expect(try residentsDescription(residents: []) == "No residents")
        #expect(try residentsDescription(residents: Array([LocationResidentModel].crowd.prefix(1)))
                == "1 resident")
        #expect(try residentsDescription(residents: .crowd) == "6 residents")
    }

    // MARK: - The publisher

    @Test("the data publisher combines the list and the selection")
    func dataPublisherCombinesBothStreams() async throws {
        let viewModel = StubLocationDetailViewModel()
        viewModel.locations = [.make(id: "1")]
        viewModel.selectedId = "1"
        let mapper = LocationDetailSectionMapper(viewModel: viewModel)

        var received: LocationDetailSectionMapper.DataModel?
        let cancellable = mapper.dataPublisher(viewModel).sink { received = $0 }
        defer { cancellable.cancel() }

        let data = try #require(received)
        #expect(data.locations?.map(\.id) == ["1"])
        #expect(data.selectedId == "1")
    }

    // MARK: - Helpers

    private func map(_ data: LocationDetailSectionMapper.DataModel) -> LocationDetailRenderModel {
        LocationDetailSectionMapper(viewModel: StubLocationDetailViewModel()).mapToRenderModel(data)
    }

    private func content(_ render: LocationDetailRenderModel) throws -> LocationDetailContent {
        guard case .visible(let content) = render else {
            throw MapperExpectationError.notVisible
        }
        return content
    }

    private func residentsDescription(residents: [LocationResidentModel]) throws -> String {
        try content(map(.make(locations: [.make(id: "1", residents: residents)], selectedId: "1")))
            .residentsDescription
    }
}

extension LocationDetailSectionMapper.DataModel {
    static func make(locations: [LocationModel]? = [],
                     selectedId: String? = nil) -> Self {
        Self(locations: locations, selectedId: selectedId)
    }
}
