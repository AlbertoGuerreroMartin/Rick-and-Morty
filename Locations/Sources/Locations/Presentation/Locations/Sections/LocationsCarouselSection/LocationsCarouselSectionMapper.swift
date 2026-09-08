//
//  LocationsCarouselSectionMapper.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine
import Core
import Foundation

/// One circle on the carousel, reduced to the string it draws. No subtitle: the card below
/// already describes the focused location in full.
struct LocationsCarouselItemRenderModel: Equatable, Identifiable {
    let id: String
    let title: String
}

enum LocationsCarouselRenderModel: Equatable {
    case hidden
    case empty(LocationsSectionEmptyReason)
    case visible(items: [LocationsCarouselItemRenderModel],
                 selectedId: String?,
                 footer: LocationsSectionFooter)
}

protocol LocationsCarouselSectionMapperContract: SectionMapperContract {}

/// Turns what was loaded, what is selected and where pagination stands into the
/// carousel.
@MainActor
final class LocationsCarouselSectionMapper: LocationsCarouselSectionMapperContract {
    typealias ViewModel = LocationsCarouselSectionViewModelContract
    typealias RenderModel = LocationsCarouselRenderModel

    struct DataModel {
        let isLoading: Bool
        let locations: [LocationModel]?
        let pagination: LocationsPaginationState
        let loadFailed: Bool
        let selectedId: String?
    }

    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    /// Nested, not a single `combineLatest`: Combine's operator tops out at four streams.
    func dataPublisher(_ viewModel: ViewModel) -> AnyPublisher<DataModel, Never> {
        let list = viewModel.loadingPublisher
            .combineLatest(viewModel.locationsPublisher, viewModel.paginationPublisher)
        let focus = viewModel.loadFailedPublisher
            .combineLatest(viewModel.selectedLocationIdPublisher)

        return list.combineLatest(focus)
            .map { list, focus in
                DataModel(isLoading: list.0,
                          locations: list.1,
                          pagination: list.2,
                          loadFailed: focus.0,
                          selectedId: focus.1)
            }
            .eraseToAnyPublisher()
    }

    func mapToRenderModel(_ data: DataModel) -> LocationsCarouselRenderModel {
        guard !data.isLoading else {
            return .hidden
        }

        // `nil` means no page has ever landed, distinct from "zero locations".
        guard let locations = data.locations else {
            return .hidden
        }

        guard !locations.isEmpty else {
            return .empty(data.loadFailed ? .failed : .noLocations)
        }

        return .visible(items: locations.map(Self.item),
                        selectedId: data.selectedId,
                        footer: footer(for: data.pagination))
    }

    private static func item(_ location: LocationModel) -> LocationsCarouselItemRenderModel {
        LocationsCarouselItemRenderModel(id: location.id, title: location.name)
    }

    private func footer(for state: LocationsPaginationState) -> LocationsSectionFooter {
        switch state {
        case .idle: .loadMore
        case .loading: .loading
        case .failed: .retry
        case .end: .none
        }
    }
}
