//
//  StubLocationsCarouselViewModel.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Combine
import Foundation
@testable import Locations

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
