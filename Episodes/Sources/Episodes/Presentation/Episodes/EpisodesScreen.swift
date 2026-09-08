//
//  EpisodesScreen.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Core
import Foundation
import Storage
import SwiftUI

struct EpisodesScreen<Content: View>: View {
    // `Owned`, not an observed view model, so a view-model publish doesn't re-evaluate this body.
    @StateObject private var graph: Owned<EpisodesScreenGraph>
    private let makeSection: (EpisodesScreenGraph) -> Content

    /// `AnyView`: the destination is a screen from another package; see `EpisodesExternalDestinations`.
    private let makeDestination: (EpisodesRoute) -> AnyView

    /// Write-only mirror pushed into the view model; `.searchable` needs a `Binding`.
    @State private var searchText = ""

    init(makeGraph: @escaping () -> EpisodesScreenGraph,
         makeSection: @escaping (EpisodesScreenGraph) -> Content,
         makeDestination: @escaping (EpisodesRoute) -> AnyView) {
        _graph = StateObject(wrappedValue: Owned(makeGraph))
        self.makeSection = makeSection
        self.makeDestination = makeDestination
    }

    var body: some View {
        // Bound to the navigator's path so a tap and a programmatic push land in the same array.
        NavigationStack(path: Bindable(graph.value.navigator).path) {
            makeSection(graph.value)
                // Declared once for the whole stack: every row pushes the same route case.
                .navigationDestination(for: EpisodesRoute.self) { makeDestination($0) }
                .navigationTitle("Episodes")
                .searchable(text: $searchText,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "Search episodes")
                // Episode titles are puns on proper nouns; autocorrect would rewrite the query.
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: searchText) { _, text in
                    graph.value.viewModel.updateSearchText(text)
                }
                // Cache cleared elsewhere (dev tools) triggers a reload.
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
    EpisodesScreen(
        makeGraph: {
            let useCase = EpisodesUseCase(repository: PreviewEpisodesRepository())
            let viewModel = EpisodesViewModel(episodesUseCase: useCase)
            return EpisodesScreenGraph(navigator: EpisodesNavigator(),
                                       viewModel: viewModel,
                                       listMapper: EpisodesListSectionMapper(viewModel: viewModel))
        },
        makeSection: { graph in
            EpisodesListSectionView(viewModel: graph.viewModel, mapper: graph.listMapper)
        },
        makeDestination: { route in
            switch route {
            case .character(let id):
                AnyView(Text("Character \(id)"))
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
