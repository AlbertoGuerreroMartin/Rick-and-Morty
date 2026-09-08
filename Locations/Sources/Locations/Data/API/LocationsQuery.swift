//
//  LocationsQuery.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Networking

/// One page of the `locations` root field.
///
/// `page` is the only variable this feature ever sends. The schema does offer a
/// location filter — name, type, dimension — but this screen has no search: the
/// carousel is a place to *travel* through 126 locations, not a place to query
/// them, and a filter argument would be dead weight that also fragmented the
/// cache key per keystroke for a control that does not exist.
///
/// With `page` as the single declared property, `GraphQLPaginatedQuery` emits
/// `locations(page: $page)` and no `filter: { ... }` argument at all — the
/// builder drops an empty filter object rather than sending `filter: {}`, which
/// the server would reject.
struct LocationsQuery: GraphQLPaginatedQuery {
    typealias ResponseEntity = LocationEntity

    static var objectRequested: String { "locations" }

    let page: Int?

    init(page: Int? = nil) {
        self.page = page
    }
}
