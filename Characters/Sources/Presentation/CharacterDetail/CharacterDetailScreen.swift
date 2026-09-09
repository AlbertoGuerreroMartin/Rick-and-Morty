//
//  CharacterDetailScreen.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Core
import Foundation
import Networking
import Storage
import SwiftUI

struct CharacterDetailScreen<Content: View>: View {
    // `Owned`, not a directly-observed `@StateObject`: the view model must not
    // trigger this body on every `@Published` write, only the sections should.
    @StateObject private var scope: Owned<DependencyContainer>
    private let makeSections: (DependencyContainer) -> Content

    init(makeScope: @escaping () -> DependencyContainer,
         @ViewBuilder makeSections: @escaping (DependencyContainer) -> Content) {
        _scope = StateObject(wrappedValue: Owned(makeScope))
        self.makeSections = makeSections
    }

    var body: some View {
        // No `NavigationStack` of its own: this screen is pushed into the Characters stack.
        ScrollView {
            // `spacing: 0`: the info card is pulled up over the header with negative
            // padding, and a stack spacing would fight it.
            VStack(spacing: 0) {
                makeSections(scope.value)
            }
        }
        // The picture runs under the navigation bar, so its background is hidden.
        .ignoresSafeArea(edges: .top)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await scope.value.resolve((any CharacterDetailViewModelContract).self).loadData()
        }
        // A cache clear from the developer tools is announced via `Storage`
        // notification; the screen answers by reloading from scratch.
        .onReceive(NotificationCenter.default.publisher(for: .cacheDidClear)) { _ in
            Task { await scope.value.resolve((any CharacterDetailViewModelContract).self).reloadFromScratch() }
        }
    }
}

#Preview {
    NavigationStack {
        CharacterDetailScreen(
            makeScope: {
                let root = DependencyContainer()
                CharactersAssembly.register(in: root,
                                            dependencies: PreviewCharactersDependencies(),
                                            navigator: CharactersNavigator())
                // Last wins: the real wiring, cut off at the repository so nothing reaches the network.
                root.register((any CharactersRepositoryContract).self) { _ in PreviewCharacterDetailRepository() }
                let scope = root.makeChild()
                scope.register(CharacterDetailContext.self) { _ in CharacterDetailContext(id: "1") }
                return scope
            },
            makeSections: { scope in
                CharacterDetailHeaderSectionView(
                    viewModel: scope.resolve((any CharacterDetailHeaderSectionViewModelContract).self),
                    renderModelPublisher: scope.resolve(CharacterDetailHeaderSectionMapper.self).renderModelPublisher()
                )
                CharacterDetailInfoSectionView(
                    viewModel: scope.resolve((any CharacterDetailInfoSectionViewModelContract).self),
                    renderModelPublisher: scope.resolve(CharacterDetailInfoSectionMapper.self).renderModelPublisher()
                )
                CharacterDetailEpisodesSectionView(
                    viewModel: scope.resolve((any CharacterDetailEpisodesSectionViewModelContract).self),
                    renderModelPublisher: scope.resolve(CharacterDetailEpisodesSectionMapper.self).renderModelPublisher()
                )
            }
        )
    }
}

/// Stands in for the repository, skipping the cache, network and mappers. Links half the
/// episodes so the canvas exercises the join rather than a pre-linked model.
private struct PreviewCharacterDetailRepository: CharactersRepositoryContract {
    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage {
        CharactersPage(characters: [], nextPage: nil)
    }

    func fetchCharacterDetail(id: String) async throws -> CharacterDetailModel {
        CharacterDetailModel(
            id: id,
            name: "Rick Sanchez",
            status: .alive,
            species: "Human",
            type: nil,
            gender: .male,
            image: URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")!,
            origin: CharacterDetailPlaceModel(name: "Earth (C-137)",
                                              type: "Planet",
                                              dimension: "Dimension C-137"),
            location: CharacterDetailPlaceModel(name: "Citadel of Ricks",
                                                type: "Space station",
                                                dimension: "unknown"),
            episodes: (1...8).map { number in
                CharacterDetailEpisodeModel(id: "\(number)",
                                            name: "Episode \(number)",
                                            airDate: "December \(number), 2013",
                                            code: String(format: "S01E%02d", number),
                                            season: 1,
                                            number: number,
                                            hboMaxURL: nil)
            }
        )
    }

    func fetchHBOMaxLinks() async throws -> HBOMaxLinks {
        let urls = stride(from: 2, through: 8, by: 2).reduce(into: [EpisodeNumber: URL]()) { urls, number in
            urls[EpisodeNumber(season: 1, number: number)] =
                URL(string: "https://play.hbomax.com/video/watch/ef7d1c40-2ecc-471a-81a5-7fe06400240a")
        }
        return HBOMaxLinks(urls: urls)
    }
}

/// Feeds `CharactersAssembly` in the preview; every registration that would use these is overridden.
private struct PreviewCharactersDependencies: CharactersDependencies {
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
