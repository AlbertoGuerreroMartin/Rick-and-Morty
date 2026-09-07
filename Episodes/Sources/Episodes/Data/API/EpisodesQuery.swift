//
//  EpisodesQuery.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking

/// One page of the `episodes` root field.
///
/// `page` is the only variable the feature ever sends. That is not a shortcut:
/// the schema's episode filter matches on name and episode code, and this
/// screen deliberately searches locally over the whole catalogue rather than
/// asking the server (see `EpisodesSearchQuery`), so a filter argument would be
/// dead weight that also fragmented the cache key per keystroke.
///
/// With `page` as the single declared property, `GraphQLPaginatedQuery` emits
/// `episodes(page: $page)` and no `filter: { ... }` argument at all — the
/// builder drops an empty filter object rather than sending `filter: {}`, which
/// the server would reject.
struct EpisodesQuery: GraphQLPaginatedQuery {
    typealias ResponseEntity = EpisodeEntity

    static var objectRequested: String { "episodes" }

    let page: Int?

    init(page: Int? = nil) {
        self.page = page
    }
}
