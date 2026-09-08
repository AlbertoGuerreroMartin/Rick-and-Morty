//
//  LocationsScreenGraph.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

/// The object graph owned by a `LocationsScreen` instance.
///
/// Built exactly once per screen identity and held by the screen through
/// `Owned`. It carries the view model *and* both section mappers so each section
/// receives the very same publisher instance on each parent body evaluation,
/// avoiding re-subscription churn — which matters more here than on a list
/// screen, because a re-subscribed carousel would re-run its "items arrived"
/// announcement and yank the focus back to the first location.
@MainActor
struct LocationsScreenGraph {
    let viewModel: LocationsViewModel
    let carouselMapper: LocationsCarouselSectionMapper
    let detailMapper: LocationDetailSectionMapper
}
