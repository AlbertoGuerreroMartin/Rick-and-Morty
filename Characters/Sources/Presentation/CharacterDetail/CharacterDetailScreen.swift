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
    // The graph lives in `Owned` rather than the view model living directly in
    // `@StateObject`: `@StateObject` is what keeps the graph alive for the
    // screen's identity, but it also observes. An observable view model would
    // fire `objectWillChange` on every `@Published` write and re-evaluate this
    // whole body, while the architecture wants only the sections to re-render
    // (view model publishers -> mapper -> section `@State`). `Owned` never
    // publishes anything, so we get the ownership without the observation.
    @StateObject private var graph: Owned<CharacterDetailScreenGraph>
    private let makeSections: (CharacterDetailScreenGraph) -> Content

    init(makeGraph: @escaping () -> CharacterDetailScreenGraph,
         @ViewBuilder makeSections: @escaping (CharacterDetailScreenGraph) -> Content) {
        _graph = StateObject(wrappedValue: Owned(makeGraph))
        self.makeSections = makeSections
    }

    var body: some View {
        // No `NavigationStack` of its own: this screen is *pushed* into the
        // Characters stack, and nesting a second one would give it its own
        // toolbar, its own back button and a title bar the picture could not run
        // under.
        ScrollView {
            // `spacing: 0` because the sections space themselves: the info card
            // is deliberately pulled *up* over the header with a negative
            // padding, and a stack spacing would fight it.
            VStack(spacing: 0) {
                makeSections(graph.value)
            }
        }
        // The picture runs edge to edge and under the navigation bar, which is
        // the point of hiding the bar's background: a translucent bar over the
        // image reads as part of the photograph rather than as a strip on top of
        // it. The back button stays, drawn over the picture.
        .ignoresSafeArea(edges: .top)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await graph.value.viewModel.loadData()
        }
        // A cache wiped behind this screen's back — from the developer tools —
        // is announced through `Storage`, and the screen answers by loading
        // again from scratch. Neither side knows the other exists: the tool does
        // not know this screen, and this screen does not know the tool; the
        // notification is the only thing they share. See `CacheClearedNotification`.
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
                CharacterDetailHeaderSectionView(viewModel: graph.viewModel, mapper: graph.headerMapper)
                CharacterDetailInfoSectionView(mapper: graph.infoMapper)
                CharacterDetailEpisodesSectionView(mapper: graph.episodesMapper)
            }
        )
    }
}

/// Stubbed at the repository seam rather than the data-source one: the preview
/// wants a canned domain model, and standing in for the repository skips the
/// cache, the network and the two mappers in one substitution.
///
/// The links come back real, so the canvas exercises the join rather than a
/// pre-linked model: half the rows get a play button and half do not, which is
/// what the screen actually looks like.
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

    /// Every other episode, so the canvas shows both a linked row and an
    /// unlinked one without a JustWatch request.
    func fetchHBOMaxLinks() async throws -> HBOMaxLinks {
        let urls = stride(from: 2, through: 8, by: 2).reduce(into: [EpisodeNumber: URL]()) { urls, number in
            urls[EpisodeNumber(season: 1, number: number)] =
                URL(string: "https://play.hbomax.com/video/watch/ef7d1c40-2ecc-471a-81a5-7fe06400240a")
        }
        return HBOMaxLinks(urls: urls)
    }
}
