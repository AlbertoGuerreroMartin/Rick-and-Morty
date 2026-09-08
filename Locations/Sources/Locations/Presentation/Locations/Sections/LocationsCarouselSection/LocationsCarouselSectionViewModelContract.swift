//
//  LocationsCarouselSectionViewModelContract.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine

// Main-actor isolated: the conforming view models, the mapper and the section
// views all live on the main actor, and `@Published` projected values can only
// be read from the view model's own isolation domain.
@MainActor
protocol LocationsCarouselSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }

    /// Every location loaded so far, unfiltered. `nil` means no page has ever
    /// landed — a state the mapper needs to tell apart from an empty answer,
    /// because one draws a spinner and the other draws an empty state.
    var locationsPublisher: AnyPublisher<[LocationModel]?, Never> { get }

    var paginationPublisher: AnyPublisher<LocationsPaginationState, Never> { get }

    /// Whether the last (re)load of page 1 failed. Distinguishes "there are no
    /// locations" from "we could not ask", which need different copy and only
    /// one of which gets a button.
    var loadFailedPublisher: AnyPublisher<Bool, Never> { get }

    /// Which location is at the centre of the carousel. The section reads it to
    /// scroll itself when the selection changes from *outside* — after a reload,
    /// most of all, when the id it was showing no longer exists.
    var selectedLocationIdPublisher: AnyPublisher<String?, Never> { get }

    /// Asks for the next page. Idempotent while a page is in flight, and a no-op
    /// at the end of the list, so the section can call it from a focus change
    /// without guarding anything itself.
    func loadNextPage() async

    /// Re-asks for page 1. Drives the Retry button of the failed empty state.
    func retryLoad()

    /// Reports the circle that settled at the centre. The view model decides
    /// whether that is a change worth publishing.
    func selectLocation(id: String)
}
