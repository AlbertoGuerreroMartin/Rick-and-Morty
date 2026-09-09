//
//  LocationsScreen.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Core
import Foundation
import Networking
import Storage
import SwiftUI

struct LocationsScreen<Content: View, Destination: View>: View {
    // `Owned`, not the view model directly in `@StateObject`: keeps the scope alive without
    // observing it, so a `@Published` write re-renders only the sections, not this body.
    @StateObject private var scope: Owned<DependencyContainer>
    private let makeSection: (DependencyContainer) -> Content

    /// Generic, not erased: the destination is a screen from another package; see `LocationsExternalDestinations`.
    private let makeDestination: (LocationsRoute) -> Destination

    init(makeScope: @escaping () -> DependencyContainer,
         makeSection: @escaping (DependencyContainer) -> Content,
         @ViewBuilder makeDestination: @escaping (LocationsRoute) -> Destination) {
        _scope = StateObject(wrappedValue: Owned(makeScope))
        self.makeSection = makeSection
        self.makeDestination = makeDestination
    }

    var body: some View {
        // Bound to the navigator's path so a tap and a programmatic push land in the same array.
        NavigationStack(path: Bindable(scope.value.resolve(LocationsNavigator.self)).path) {
            makeSection(scope.value)
                // Declared once for the whole stack: every row pushes the same route case.
                .navigationDestination(for: LocationsRoute.self) { makeDestination($0) }
                .navigationTitle(Text("Locations", bundle: .module))
                // Reloads on a cache clear announced via `Storage` (e.g. from developer tools).
                .onReceive(NotificationCenter.default.publisher(for: .cacheDidClear)) { _ in
                    Task { await scope.value.resolve((any LocationsViewModelContract).self).reloadFromScratch() }
                }
        }
        .task {
            await scope.value.resolve((any LocationsViewModelContract).self).loadData()
        }
    }
}

#Preview {
    let root = DependencyContainer()
    LocationsAssembly.register(in: root,
                               dependencies: PreviewLocationsDependencies(),
                               navigator: LocationsNavigator())
    // Last wins: the real wiring, cut off at the repository so nothing reaches the network.
    root.register((any LocationsRepositoryContract).self) { _ in PreviewLocationsRepository() }
    return LocationsScreen(
        makeScope: { root.makeChild() },
        makeSection: { scope in
            VStack(spacing: 0) {
                LocationsCarouselSectionView(
                    viewModel: scope.resolve((any LocationsCarouselSectionViewModelContract).self),
                    renderModelPublisher: scope.resolve(LocationsCarouselSectionMapper.self).renderModelPublisher()
                )
                LocationDetailSectionView(
                    viewModel: scope.resolve((any LocationDetailSectionViewModelContract).self),
                    renderModelPublisher: scope.resolve(LocationDetailSectionMapper.self).renderModelPublisher()
                )
            }
        },
        makeDestination: { route in
            switch route {
            case .character(let id):
                Text("Character \(id)")
            }
        }
    )
}

/// Feeds `LocationsAssembly` in the preview; every registration that would use these is overridden.
private struct PreviewLocationsDependencies: LocationsDependencies {
    let graphQLClient = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!)
    let cacheStore: any CacheStoreContract = PreviewCacheStore()
}

/// Stores nothing: the preview never reaches the cache, but the wiring still asks for a store.
private struct PreviewCacheStore: CacheStoreContract {
    func entry<Value: Codable & Sendable>(for key: CacheKey, as type: Value.Type) async throws -> CacheEntry<Value>? { nil }
    func store<Value: Codable & Sendable>(_ value: Value, for key: CacheKey, lifetime: TimeInterval) async throws {}
    func remove(_ key: CacheKey) async throws {}
    func removeAll(in namespace: String) async throws {}
    func removeExpired() async throws {}
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
