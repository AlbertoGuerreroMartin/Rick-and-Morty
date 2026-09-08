//
//  LocationsExternalDestinations.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import SwiftUI

/// Screens this feature pushes but does not own. `Locations` cannot import `Characters`, so the
/// composition root supplies the view, type-erased as `AnyView`.
@MainActor
public protocol LocationsExternalDestinations {
    /// Must declare no `NavigationStack` of its own; this feature's stack presents it.
    func characterDetail(id: String) -> AnyView
}
