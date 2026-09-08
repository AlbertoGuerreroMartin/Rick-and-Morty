//
//  EpisodesNavigator.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import SwiftUI

/// `@Observable`, not `ObservableObject`, so reading only `path` via `Bindable` isn't invalidated
/// by anything else. Owned by the app's container: a tab root's stack must outlive the screen.
@MainActor
@Observable
public final class EpisodesNavigator {
    var path: [EpisodesRoute] = []

    public init() {}

    func push(_ route: EpisodesRoute) { path.append(route) }

    func pop() { _ = path.popLast() }

    func popToRoot() { path.removeAll() }

    /// Appends rather than replacing the path (opposite of `CharactersNavigator.showCharacter`):
    /// this is a detour from the catalogue, and back should return to the row, not the list top.
    public func showCharacter(id: String) {
        push(.character(id: id))
    }
}
