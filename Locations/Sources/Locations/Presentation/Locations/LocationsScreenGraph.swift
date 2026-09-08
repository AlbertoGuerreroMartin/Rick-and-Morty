//
//  LocationsScreenGraph.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

/// The object graph owned by a `LocationsScreen`, built once per screen identity via `Owned`.
/// Carries both mappers so re-subscribing on each body evaluation can't yank the carousel focus back.
@MainActor
struct LocationsScreenGraph {
    let viewModel: LocationsViewModel
    let carouselMapper: LocationsCarouselSectionMapper
    let detailMapper: LocationDetailSectionMapper
}
