//
//  LocationsCarouselSectionMapper.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine
import Core
import Foundation

/// One circle on the carousel, already reduced to the string it draws.
///
/// The name is baked here rather than interpolated in the view, for the reason
/// every render model in this app bakes its copy: what an item says is
/// behaviour, and behaviour that lives in a `Text` can only be checked by
/// looking at a screenshot.
///
/// There is deliberately no subtitle. A circle has room for one thing, and the
/// card below it is already describing the focused location in full — a type
/// squeezed under a name inside 150 points would be a second, worse copy of a
/// row the user is looking at anyway.
struct LocationsCarouselItemRenderModel: Equatable, Identifiable {
    /// The location's id, which is also what the section reports back as the
    /// selection — never an index, which means something different after every
    /// page lands.
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

    /// Five publishers through two `combineLatest`s: Combine's operator tops out
    /// at four streams, so the pair is nested rather than the view model growing
    /// a single pre-combined "state" publisher — which would defeat the point of
    /// per-property publishers, since every section would then wake for every
    /// change.
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

    /// The order of these rules *is* the screen's behaviour, so they are written
    /// as one straight line of early returns rather than a nest of conditions.
    func mapToRenderModel(_ data: DataModel) -> LocationsCarouselRenderModel {
        guard !data.isLoading else {
            return .hidden
        }

        // `nil` is "no page has ever landed", which is not the same as "zero
        // locations" and must not draw an empty state.
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

    /// The name and nothing else. Everything else a location has — its type, its
    /// dimension, who lives there — is a row on the card below, which is the
    /// half of the screen that has room to be read.
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
