//
//  EpisodesQuery.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking

/// `page` is the only variable sent: search happens locally, so a filter would just fragment the
/// cache key. With no filter property, the builder omits `filter:` rather than sending `filter: {}`.
struct EpisodesQuery: GraphQLPaginatedQuery {
    typealias ResponseEntity = EpisodeEntity

    static var objectRequested: String { "episodes" }

    let page: Int?

    init(page: Int? = nil) {
        self.page = page
    }
}
