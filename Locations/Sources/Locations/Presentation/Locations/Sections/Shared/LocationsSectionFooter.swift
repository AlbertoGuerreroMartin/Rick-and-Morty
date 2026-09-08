//
//  LocationsSectionFooter.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

/// What the last stop on the carousel is, once the circles for the loaded
/// locations are drawn.
///
/// The view never sees `LocationsPaginationState`: the difference between
/// `.idle` and `.loading` is a trigger detail, and both draw the same spinner in
/// `LocationsCarouselPaginationItemView`. The page number inside the state's
/// cases is deliberately not here either — the view has no use for it, and
/// giving it one would be a second place for "which page is next" to live.
enum LocationsSectionFooter: Equatable {
    /// Nothing loading yet, and there is a page waiting — the pagination item's
    /// `.task` is what asks for it, once the user scrolls far enough for the
    /// lazy row to build it.
    case loadMore
    case loading
    case retry
    case none
}
