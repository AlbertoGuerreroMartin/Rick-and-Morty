//
//  LocationsNavigator.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import SwiftUI

/// `@Observable`, not `ObservableObject`, so reading only `path` via `Bindable` isn't invalidated
/// by anything else. Owned by the app's container: a tab root's stack must outlive the screen.
@MainActor
@Observable
public final class LocationsNavigator {
    var path: [LocationsRoute] = []

    public init() {}

    func push(_ route: LocationsRoute) { path.append(route) }

    func pop() { _ = path.popLast() }

    func popToRoot() { path.removeAll() }

    /// Appends rather than replacing the path (opposite of `CharactersNavigator.showCharacter`):
    /// this is a detour from the location card, and back should return to it.
    public func showCharacter(id: String) {
        push(.character(id: id))
    }
}
