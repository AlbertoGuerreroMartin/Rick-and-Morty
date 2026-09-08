//
//  LocationsScreen.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Core
import Foundation
import Storage
import SwiftUI

struct LocationsScreen<Content: View>: View {
    // `Owned`, not the view model directly in `@StateObject`: keeps the graph alive without
    // observing it, so a `@Published` write re-renders only the sections, not this body.
    @StateObject private var graph: Owned<LocationsScreenGraph>
    private let makeSection: (LocationsScreenGraph) -> Content

    /// `AnyView`: the destination is a screen from another package; see `LocationsExternalDestinations`.
    private let makeDestination: (LocationsRoute) -> AnyView

    init(makeGraph: @escaping () -> LocationsScreenGraph,
         makeSection: @escaping (LocationsScreenGraph) -> Content,
         makeDestination: @escaping (LocationsRoute) -> AnyView) {
        _graph = StateObject(wrappedValue: Owned(makeGraph))
        self.makeSection = makeSection
        self.makeDestination = makeDestination
    }

    var body: some View {
        // Bound to the navigator's path so a tap and a programmatic push land in the same array.
        NavigationStack(path: Bindable(graph.value.navigator).path) {
            makeSection(graph.value)
                // Declared once for the whole stack: every row pushes the same route case.
                .navigationDestination(for: LocationsRoute.self) { makeDestination($0) }
                .navigationTitle("Locations")
                // Reloads on a cache clear announced via `Storage` (e.g. from developer tools).
                .onReceive(NotificationCenter.default.publisher(for: .cacheDidClear)) { _ in
                    Task { await graph.value.viewModel.reloadFromScratch() }
                }
        }
        .task {
            await graph.value.viewModel.loadData()
        }
    }
}

#Preview {
    LocationsFactory.previewScreen(repository: PreviewLocationsRepository())
}

/// Stubbed at the repository seam so the preview skips cache, network and mapper.
/// Serves three pages so the canvas shows the end-of-list footer too.
private struct PreviewLocationsRepository: LocationsRepositoryContract {
    private static let names = ["Earth (C-137)", "Abadango", "Citadel of Ricks",
                                "Worldender's lair", "Anatomy Park"]

    func fetchLocations(page: Int) async throws -> LocationsPage {
        let locations = Self.names.enumerated().map { index, name in
            let id = "\(page)-\(index + 1)"
            return LocationModel(id: id,
                                 name: "\(name) \(page)",
                                 // Every third location has no type, so the canvas shows both row shapes.
                                 type: index.isMultiple(of: 3) ? nil : "Planet",
                                 dimension: index.isMultiple(of: 2) ? "Dimension C-137" : "unknown",
                                 residents: (0..<10).map { resident in
                                     LocationResidentModel(
                                        id: "\(id)-\(resident)",
                                        name: "\(resident)",
                                        status: .alive,
                                        species: "Human",
                                        image: URL(string: "https://rickandmortyapi.com/api/character/avatar/\(resident + 1).jpeg")!
                                     )
                                 })
        }
        return LocationsPage(locations: locations, nextPage: page < 3 ? page + 1 : nil)
    }
}
