//
//  LocationEntityDebugTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation
import Testing
@testable import Locations

/// The debug descriptions are hand-written, which is the only reason they are
/// worth a test: they are what someone reads in a breakpoint when a page comes
/// back with a hole in it, and a property added to the entity that never reaches
/// the description is a field that silently stops being debuggable.
///
/// They must also stay *computed* — `@Document` skips computed properties, so a
/// stored one here would end up in the selection set and be sent to the server.
@Suite("LocationEntity debugging")
struct LocationEntityDebugTests {

    @Test("a complete entity prints every field")
    func completeEntityPrintsEverything() {
        let description = LocationEntity.make().debugDescription

        #expect(description.contains("LocationEntity"))
        #expect(description.contains("id:        1"))
        #expect(description.contains("name:      Earth (C-137)"))
        #expect(description.contains("type:      Planet"))
        #expect(description.contains("dimension: Dimension C-137"))
        // The count, not the residents: a location can have hundreds, and a
        // breakpoint that printed all of them would bury the four fields above.
        #expect(description.contains("residents: 2"))
    }

    @Test("absent fields print as nil rather than as blanks")
    func absentFieldsPrintAsNil() {
        let description = LocationEntity(id: nil, name: nil, type: nil,
                                         dimension: nil, residents: nil).debugDescription

        #expect(description.contains("id:        nil"))
        #expect(description.contains("name:      nil"))
        #expect(description.contains("type:      nil"))
        #expect(description.contains("dimension: nil"))
        #expect(description.contains("residents: nil"))
    }

    /// Zero residents and *no* residents array are different answers from the
    /// server, and the description keeps them apart.
    @Test("an empty resident list prints as a count of zero")
    func emptyResidentsPrintAsZero() {
        #expect(LocationEntity.make(residents: []).debugDescription.contains("residents: 0"))
    }

    @Test("a resident prints its id and its image")
    func residentPrintsItself() {
        let resident = LocationResidentEntity(id: "7", name: "Rick Sanchez", image: URL(string: "https://example.com/7.jpeg"))

        #expect(resident.debugDescription == "Resident(id: 7, image: https://example.com/7.jpeg)")
    }

    @Test("an empty resident prints nil on both halves")
    func emptyResidentPrintsNil() {
        #expect(LocationResidentEntity(id: nil, name: nil, image: nil).debugDescription
                == "Resident(id: nil, image: nil)")
    }
}
