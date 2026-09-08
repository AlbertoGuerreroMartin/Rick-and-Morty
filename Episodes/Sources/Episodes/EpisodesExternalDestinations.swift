//
//  EpisodesExternalDestinations.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import SwiftUI

/// Screens this feature pushes but does not own. `Episodes` cannot import `Characters`, so the
/// composition root supplies the view as an associated type, so nothing is erased to `AnyView`.
@MainActor
public protocol EpisodesExternalDestinations {
    associatedtype CharacterDetail: View

    /// Must declare no `NavigationStack` of its own; this feature's stack presents it.
    func characterDetail(id: String) -> CharacterDetail
}
