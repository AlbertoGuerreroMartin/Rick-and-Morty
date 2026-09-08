//
//  RickMortyExternalNavigator.swift
//  RickMorty
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Characters
import Episodes
import Locations
import SwiftUI

/// Where features are joined: the one file that imports all of them. Feature packages can't
/// import each other (enforced via `Package.swift`), so a feature declares the cross-feature
/// destination it needs (e.g. `EpisodesExternalDestinations`) and the composition root supplies
/// it — the same shape as `*Dependencies` one layer up.
///
/// Main-actor because building a view is main-actor work; holds the whole container since a
/// destination is a screen graph away from the app's infrastructure.
@MainActor
final class RickMortyExternalNavigator {
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }
}

extension RickMortyExternalNavigator: EpisodesExternalDestinations, LocationsExternalDestinations {
    /// The Characters feature's detail screen, pushed onto the host stack. Returns the
    /// screen alone (no `NavigationStack`) so it inherits the host's back button. One opaque
    /// return satisfies both protocols' `CharacterDetail` associated types.
    func characterDetail(id: String) -> some View {
        CharactersFactory.buildCharacterDetail(dependencies: container, id: id)
    }
}
