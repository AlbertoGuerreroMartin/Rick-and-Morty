//
//  StubExternalDestinations.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
import SwiftUI
@testable import Locations

@MainActor
final class StubExternalDestinations: LocationsExternalDestinations {
    private(set) var requestedIds: [String] = []

    func characterDetail(id: String) -> some View {
        requestedIds.append(id)
        return Text(id)
    }
}
