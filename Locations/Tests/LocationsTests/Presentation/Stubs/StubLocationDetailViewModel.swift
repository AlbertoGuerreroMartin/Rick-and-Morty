//
//  StubLocationDetailViewModel.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Combine
import Foundation
@testable import Locations

@MainActor
final class StubLocationDetailViewModel: LocationDetailSectionViewModelContract {
    var locations: [LocationModel]?
    var selectedId: String?

    var locationsPublisher: AnyPublisher<[LocationModel]?, Never> { Just(locations).eraseToAnyPublisher() }
    var selectedLocationIdPublisher: AnyPublisher<String?, Never> {
        Just(selectedId).eraseToAnyPublisher()
    }
}
