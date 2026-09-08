//
//  LocationsCarouselSectionViewModelContract.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine

@MainActor
protocol LocationsCarouselSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }

    /// `nil` means no page has ever landed, distinct from an empty answer (spinner vs. empty state).
    var locationsPublisher: AnyPublisher<[LocationModel]?, Never> { get }

    var paginationPublisher: AnyPublisher<LocationsPaginationState, Never> { get }

    /// Distinguishes "no locations" from "couldn't ask"; only one gets a retry button.
    var loadFailedPublisher: AnyPublisher<Bool, Never> { get }

    var selectedLocationIdPublisher: AnyPublisher<String?, Never> { get }

    /// Idempotent while a page is in flight, and a no-op at the end of the list.
    func loadNextPage() async

    func retryLoad()

    func selectLocation(id: String)
}
