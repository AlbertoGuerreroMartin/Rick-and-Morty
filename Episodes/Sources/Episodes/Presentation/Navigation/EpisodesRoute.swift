//
//  EpisodesRoute.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

/// One enum per stack turns a mistyped `NavigationLink` destination into a compile error rather
/// than a silently-ignored tap. The view itself comes from another package; see
/// `EpisodesExternalDestinations`.
enum EpisodesRoute: Hashable, Sendable {
    case character(id: String)
}
