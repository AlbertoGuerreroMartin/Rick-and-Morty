//
//  LocationsQuery.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Networking

/// One page of the `locations` root field. No filter: the server rejects an empty `filter: {}`,
/// so `GraphQLPaginatedQuery` omits the argument entirely when only `page` is declared.
struct LocationsQuery: GraphQLPaginatedQuery {
    typealias ResponseEntity = LocationEntity

    static var objectRequested: String { "locations" }

    let page: Int?

    init(page: Int? = nil) {
        self.page = page
    }
}
