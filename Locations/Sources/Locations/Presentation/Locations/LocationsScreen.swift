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
    // The graph lives in `Owned` rather than the view model living directly in
    // `@StateObject`: `@StateObject` is what keeps the graph alive for the
    // screen's identity, but it also observes. An observable view model would
    // fire `objectWillChange` on every `@Published` write and re-evaluate this
    // whole body, while the architecture wants only the sections to re-render
    // (view model publishers -> mapper -> section `@State`). `Owned` never
    // publishes anything, so we get the ownership without the observation.
    @StateObject private var graph: Owned<LocationsScreenGraph>
    private let makeSection: (LocationsScreenGraph) -> Content

    init(makeGraph: @escaping () -> LocationsScreenGraph,
         makeSection: @escaping (LocationsScreenGraph) -> Content) {
        _graph = StateObject(wrappedValue: Owned(makeGraph))
        self.makeSection = makeSection
    }

    var body: some View {
        NavigationStack {
            makeSection(graph.value)
                .navigationTitle("Locations")
                // A cache wiped behind this screen's back — from the developer
                // tools — is announced through `Storage`, and the screen answers
                // by loading again from scratch. Neither side knows the other
                // exists: the tool does not know this screen, and this screen
                // does not know the tool; the notification is the only thing
                // they share. See `CacheClearedNotification`.
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

/// Stubbed at the repository seam rather than the data-source one: the preview
/// wants canned domain models, and standing in for the repository skips the
/// cache, the network and the mapper in one substitution.
///
/// It serves three pages so the canvas reaches the two things a single page
/// cannot show: a carousel long enough that the focus can settle inside the last
/// three items, and the footer that appears when it does.
private struct PreviewLocationsRepository: LocationsRepositoryContract {
    private static let names = ["Earth (C-137)", "Abadango", "Citadel of Ricks",
                                "Worldender's lair", "Anatomy Park"]

    func fetchLocations(page: Int) async throws -> LocationsPage {
        let locations = Self.names.enumerated().map { index, name in
            let id = "\(page)-\(index + 1)"
            return LocationModel(id: id,
                                 name: "\(name) \(page)",
                                 // Every third location has no type, so the
                                 // canvas shows a card with a row missing as
                                 // well as a complete one.
                                 type: index.isMultiple(of: 3) ? nil : "Planet",
                                 dimension: index.isMultiple(of: 2) ? "Dimension C-137" : "unknown",
                                 residents: (0..<10).map { resident in
                                     LocationResidentModel(
                                        id: "\(id)-\(resident)",
                                        name: "\(resident)",
                                        image: URL(string: "https://rickandmortyapi.com/api/character/avatar/\(resident + 1).jpeg")!
                                     )
                                 })
        }
        return LocationsPage(locations: locations, nextPage: page < 3 ? page + 1 : nil)
    }
}
