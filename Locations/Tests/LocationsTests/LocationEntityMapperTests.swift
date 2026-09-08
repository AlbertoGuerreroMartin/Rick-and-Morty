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
        let entity = LocationEntity.make(residents: [
            LocationResidentEntity(id: nil, name: "Rick Sanchez", image: URL(string: "https://example.com/1.jpeg")),
            LocationResidentEntity(id: "2", name: "Morty Smith", image: URL(string: "https://example.com/2.jpeg"))
        ])

        #expect(try LocationEntityMapper().map(entity).residents.map(\.id) == ["2"])
    }

    @Test("a resident missing its image is skipped, not fatal")
    func residentWithoutAnImageIsSkipped() throws {
        let entity = LocationEntity.make(residents: [
            LocationResidentEntity(id: "1", name: "Rick Sanchez", image: nil),
            LocationResidentEntity(id: "2", name: "Morty Smith", image: URL(string: "https://example.com/2.jpeg"))
        ])

        #expect(try LocationEntityMapper().map(entity).residents.map(\.id) == ["2"])
    }

    @Test("absent residents map to an empty list rather than failing")
    func absentResidentsAreEmpty() throws {
        #expect(try LocationEntityMapper().map(.make(residents: nil)).residents.isEmpty)
    }

    @Test("the residents keep the API's order")
    func residentsKeepTheirOrder() throws {
        let entity = LocationEntity.make(residents: ["9", "3", "7"].map { (id: String) in
            LocationResidentEntity(id: id, name: "Resident \(id)", image: URL(string: "https://example.com/\(id).jpeg"))
        })

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
