//
//  LocationEntityMapperTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation
import Testing
@testable import Locations

@Suite("LocationEntityMapper")
struct LocationEntityMapperTests {

    @Test("a complete entity maps field for field")
    func mapsACompleteEntity() throws {
        let model = try LocationEntityMapper().map(.make())

        #expect(model.id == "1")
        #expect(model.name == "Earth (C-137)")
        #expect(model.type == "Planet")
        #expect(model.dimension == "Dimension C-137")
        #expect(model.residents.map(\.id) == ["1", "2"])
        #expect(model.residents.map(\.name) == ["Rick Sanchez", "Morty Smith"])
        #expect(model.residents.map(\.status) == [.alive, .dead])
        #expect(model.residents.map(\.species) == ["Human", "Human"])
        #expect(model.residents.map(\.image) == [URL(string: "https://example.com/1.jpeg"), URL(string: "https://example.com/2.jpeg")])
    }

    @Test("a nil entity throws")
    func nilEntityThrows() {
        #expect(throws: LocationEntityMapperError.self) {
            _ = try LocationEntityMapper().map(nil)
        }
    }

    @Test("a missing id throws")
    func missingIdThrows() {
        #expect(throws: LocationEntityMapperError.self) {
            _ = try LocationEntityMapper().map(.make(id: nil))
        }
    }

    @Test("a missing name throws")
    func missingNameThrows() {
        #expect(throws: LocationEntityMapperError.self) {
            _ = try LocationEntityMapper().map(.make(name: nil))
        }
    }

    // MARK: - Type and dimension

    @Test("a blank type normalizes to nil")
    func blankTypeIsNil() throws {
        #expect(try LocationEntityMapper().map(.make(type: "")).type == nil)
        #expect(try LocationEntityMapper().map(.make(type: "   ")).type == nil)
    }

    @Test("a blank dimension normalizes to nil")
    func blankDimensionIsNil() throws {
        #expect(try LocationEntityMapper().map(.make(dimension: "")).dimension == nil)
        #expect(try LocationEntityMapper().map(.make(dimension: " \n ")).dimension == nil)
    }

    @Test("an absent type is nil rather than an empty string")
    func absentTypeIsNil() throws {
        let model = try LocationEntityMapper().map(.make(type: nil, dimension: nil))

        #expect(model.type == nil)
        #expect(model.dimension == nil)
    }

    @Test("the API's literal unknown is kept verbatim")
    func literalUnknownIsKept() throws {
        let model = try LocationEntityMapper().map(.make(type: "unknown", dimension: "unknown"))

        #expect(model.type == "unknown")
        #expect(model.dimension == "unknown")
    }

    @Test("surrounding whitespace is trimmed rather than kept")
    func valuesAreTrimmed() throws {
        let model = try LocationEntityMapper().map(.make(type: "  Planet  ", dimension: " C-137 "))

        #expect(model.type == "Planet")
        #expect(model.dimension == "C-137")
    }

    // MARK: - Residents

    @Test("a resident missing its id is skipped, not fatal")
    func residentWithoutAnIdIsSkipped() throws {
        let entity = LocationEntity.make(residents: [.make(id: nil), .make(id: "2")])

        #expect(try LocationEntityMapper().map(entity).residents.map(\.id) == ["2"])
    }

    @Test("a resident missing its name is skipped, not fatal")
    func residentWithoutANameIsSkipped() throws {
        let entity = LocationEntity.make(residents: [.make(id: "1", name: nil), .make(id: "2")])

        #expect(try LocationEntityMapper().map(entity).residents.map(\.id) == ["2"])
    }

    @Test("a resident missing its status is skipped, not fatal")
    func residentWithoutAStatusIsSkipped() throws {
        let entity = LocationEntity.make(residents: [.make(id: "1", status: nil), .make(id: "2")])

        #expect(try LocationEntityMapper().map(entity).residents.map(\.id) == ["2"])
    }

    @Test("a resident missing its species is skipped, not fatal")
    func residentWithoutASpeciesIsSkipped() throws {
        let entity = LocationEntity.make(residents: [.make(id: "1", species: nil), .make(id: "2")])

        #expect(try LocationEntityMapper().map(entity).residents.map(\.id) == ["2"])
    }

    @Test("a resident missing its image is skipped, not fatal")
    func residentWithoutAnImageIsSkipped() throws {
        let entity = LocationEntity.make(residents: [.make(id: "1", image: nil), .make(id: "2")])

        #expect(try LocationEntityMapper().map(entity).residents.map(\.id) == ["2"])
    }

    @Test("the status is parsed regardless of the API's casing",
          arguments: [("Alive", LocationResidentStatus.alive), ("alive", .alive), ("DEAD", .dead), ("dead", .dead),
                      ("unknown", .unknown), ("Unknown", .unknown)])
    func statusIgnoresCasing(raw: String, expected: LocationResidentStatus) throws {
        let entity = LocationEntity.make(residents: [.make(status: raw)])

        #expect(try LocationEntityMapper().map(entity).residents.map(\.status) == [expected])
    }

    @Test("an unrecognized status falls back to unknown rather than dropping the resident")
    func unrecognizedStatusIsUnknown() throws {
        let entity = LocationEntity.make(residents: [.make(status: "Schrödinger"), .make(id: "2", status: "")])

        #expect(try LocationEntityMapper().map(entity).residents.map(\.status) == [.unknown, .unknown])
    }

    @Test("absent residents map to an empty list rather than failing")
    func absentResidentsAreEmpty() throws {
        #expect(try LocationEntityMapper().map(.make(residents: nil)).residents.isEmpty)
    }

    @Test("the residents keep the API's order")
    func residentsKeepTheirOrder() throws {
        let entity = LocationEntity.make(residents: ["9", "3", "7"].map { (id: String) in .make(id: id) })

        #expect(try LocationEntityMapper().map(entity).residents.map(\.id) == ["9", "3", "7"])
    }

    // MARK: - Errors

    @Test("the errors name what was missing")
    func errorsDescribeThemselves() {
        #expect(LocationEntityMapperError.noEntityError("LocationEntity").errorDescription?
            .contains("LocationEntity") == true)
        #expect(LocationEntityMapperError.missingProperty("name").errorDescription?
            .contains("name") == true)
    }
}
