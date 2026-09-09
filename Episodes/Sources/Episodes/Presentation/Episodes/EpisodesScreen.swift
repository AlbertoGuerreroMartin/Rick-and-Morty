//
//  EpisodesScreen.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Core
import Foundation
import Networking
import Storage
import SwiftUI

struct EpisodesScreen<Content: View, Destination: View>: View {
    // `Owned`, not an observed view model, so a view-model publish doesn't re-evaluate this body.
    @StateObject private var scope: Owned<DependencyContainer>
    private let makeSection: (DependencyContainer) -> Content

    /// Generic, not erased: the destination is a screen from another package; see `EpisodesExternalDestinations`.
    private let makeDestination: (EpisodesRoute) -> Destination

    /// Write-only mirror pushed into the view model; `.searchable` needs a `Binding`.
    @State private var searchText = ""

    init(makeScope: @escaping () -> DependencyContainer,
         makeSection: @escaping (DependencyContainer) -> Content,
         @ViewBuilder makeDestination: @escaping (EpisodesRoute) -> Destination) {
        _scope = StateObject(wrappedValue: Owned(makeScope))
        self.makeSection = makeSection
        self.makeDestination = makeDestination
    }

    var body: some View {
        // Bound to the navigator's path so a tap and a programmatic push land in the same array.
        NavigationStack(path: Bindable(scope.value.resolve(EpisodesNavigator.self)).path) {
            makeSection(scope.value)
                // Declared once for the whole stack: every row pushes the same route case.
                .navigationDestination(for: EpisodesRoute.self) { makeDestination($0) }
                .navigationTitle(Text("Episodes", bundle: .module))
                .searchable(text: $searchText,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: Text("Search episodes", bundle: .module))
                // Episode titles are puns on proper nouns; autocorrect would rewrite the query.
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: searchText) { _, text in
                    scope.value.resolve(EpisodesViewModel.self).updateSearchText(text)
                }
                // Cache cleared elsewhere (dev tools) triggers a reload.
                .onReceive(NotificationCenter.default.publisher(for: .cacheDidClear)) { _ in
                    Task { await scope.value.resolve(EpisodesViewModel.self).reloadFromScratch() }
                }
        }
        .task {
            await scope.value.resolve(EpisodesViewModel.self).loadData()
        }
    }
}

#Preview {
    EpisodesScreen(
        makeScope: {
            let root = DependencyContainer()
            EpisodesAssembly.register(in: root,
                                      dependencies: PreviewEpisodesDependencies(),
                                      navigator: EpisodesNavigator())
            // Last wins: the real wiring, cut off at the repository so nothing reaches the network.
            root.register((any EpisodesRepositoryContract).self) { _ in PreviewEpisodesRepository() }
            return root.makeChild()
        },
        makeSection: { scope in
            EpisodesListSectionView(
                viewModel: scope.resolve((any EpisodesListSectionViewModelContract).self),
                renderModelPublisher: scope.resolve(EpisodesListSectionMapper.self).renderModelPublisher()
            )
        },
        makeDestination: { route in
            switch route {
            case .character(let id):
                Text("Character \(id)")
            }
        }
    )
}

/// Canned domain models for the preview canvas, deliberately unordered within each season.
private struct PreviewEpisodesRepository: EpisodesRepositoryContract {
    private static let names = ["Pilot", "Lawnmower Dog", "Anatomy Park",
                                "M. Night Shaym-Aliens!", "Meeseeks and Destroy"]

    func fetchEpisodes() async throws -> [EpisodeModel] {
        (1...3).flatMap { season in
            Self.names.enumerated().reversed().map { index, name in
                let number = index + 1
                let code = String(format: "S%02dE%02d", season, number)
                return EpisodeModel(id: code,
                                    name: name,
                                    airDate: "December \(number), 201\(2 + season)",
                                    code: code,
                                    season: season,
                                    number: number,
                                    created: nil,
                                    characters: (1...(number * 2)).map { index in
                                        EpisodeCharacterModel(
                                            id: "\(code)-\(index)",
                                            name: "Character \(index)",
                                            image: URL(string: "https://rickandmortyapi.com/api/character/avatar/\(index).jpeg")!
                                        )
                                    },
                                    hboMaxURL: number.isMultiple(of: 2)
                                        ? URL(string: "https://play.hbomax.com/video/watch/ef7d1c40-2ecc-471a-81a5-7fe06400240a")
                                        : nil)
            }
        }
    }

    func fetchHBOMaxLinks() async throws -> HBOMaxLinks {
        .empty
    }
}

/// Feeds `EpisodesAssembly` in the preview; every registration that would use these is overridden.
private struct PreviewEpisodesDependencies: EpisodesDependencies {
    let graphQLClient = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!)
    let justWatchClient = GraphQLClient(endpoint: URL(string: "https://example.com/justwatch")!)
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
