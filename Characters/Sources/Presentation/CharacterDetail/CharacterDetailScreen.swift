//
//  CharacterDetailScreen.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Core
import Foundation
import Storage
import SwiftUI

struct CharacterDetailScreen<Content: View>: View {
    // `Owned`, not a directly-observed `@StateObject`: the view model must not
    // trigger this body on every `@Published` write, only the sections should.
    @StateObject private var graph: Owned<CharacterDetailScreenGraph>
    private let makeSections: (CharacterDetailScreenGraph) -> Content

    init(makeGraph: @escaping () -> CharacterDetailScreenGraph,
         @ViewBuilder makeSections: @escaping (CharacterDetailScreenGraph) -> Content) {
        _graph = StateObject(wrappedValue: Owned(makeGraph))
        self.makeSections = makeSections
    }

    var body: some View {
        // No `NavigationStack` of its own: this screen is pushed into the Characters stack.
        ScrollView {
            // `spacing: 0`: the info card is pulled up over the header with negative
            // padding, and a stack spacing would fight it.
            VStack(spacing: 0) {
                makeSections(graph.value)
            }
        }
        // The picture runs under the navigation bar, so its background is hidden.
        .ignoresSafeArea(edges: .top)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await graph.value.viewModel.loadData()
        }
        // A cache clear from the developer tools is announced via `Storage`
        // notification; the screen answers by reloading from scratch.
        .onReceive(NotificationCenter.default.publisher(for: .cacheDidClear)) { _ in
            Task { await graph.value.viewModel.reloadFromScratch() }
        }
    }
}

#Preview {
    NavigationStack {
        CharacterDetailScreen(
            makeGraph: {
                let useCase = CharacterDetailUseCase(repository: PreviewCharacterDetailRepository())
                let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)
                return CharacterDetailScreenGraph(
                    viewModel: viewModel,
                    headerMapper: CharacterDetailHeaderSectionMapper(viewModel: viewModel),
                    infoMapper: CharacterDetailInfoSectionMapper(viewModel: viewModel),
                    episodesMapper: CharacterDetailEpisodesSectionMapper(viewModel: viewModel)
                )
            },
            makeSections: { graph in
                CharacterDetailHeaderSectionView(
                    viewModel: graph.viewModel,
                    renderModelPublisher: graph.headerMapper.renderModelPublisher()
                )
                CharacterDetailInfoSectionView(
                    viewModel: graph.viewModel,
                    renderModelPublisher: graph.infoMapper.renderModelPublisher()
                )
                CharacterDetailEpisodesSectionView(
                    viewModel: graph.viewModel,
                    renderModelPublisher: graph.episodesMapper.renderModelPublisher()
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
