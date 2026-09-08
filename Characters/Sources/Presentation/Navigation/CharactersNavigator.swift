//
//  CharactersNavigator.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import SwiftUI

/// The Characters tab's navigation stack, as a value the app can hold and drive.
///
/// `@Observable` rather than `ObservableObject`: it tracks reads per property, so reading
/// only `path` (through `Bindable`) invalidates the screen without observing the rest.
/// Owned by the app's container, not the screen: a deep-link handler must reach it before
/// the screen exists. See `AppContainer`.
@MainActor
@Observable
public final class CharactersNavigator {
    /// A typed array rather than `NavigationPath`, so the destination switch stays exhaustive.
    var path: [CharactersRoute] = []

    public init() {}

    func push(_ route: CharactersRoute) { path.append(route) }

    func pop() { _ = path.popLast() }

    func popToRoot() { path.removeAll() }

    /// Deep-link entry point. Replaces the path so repeated links do not stack details.
    public func showCharacter(id: String) {
        path = [.detail(id: id)]
    }
}
