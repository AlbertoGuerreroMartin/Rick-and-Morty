//
//  EpisodesScreen.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Core
import Foundation
import SwiftUI

struct EpisodesScreen<Content: View>: View {
    // The graph lives in `Owned` rather than the view model living directly in
    // `@StateObject`: `@StateObject` is what keeps the graph alive for the
    // screen's identity, but it also observes. An observable view model would
    // fire `objectWillChange` on every `@Published` write and re-evaluate this
    // whole body, while the architecture wants only the section to re-render
    // (view model publishers -> mapper -> section `@State`). `Owned` never
    // publishes anything, so we get the ownership without the observation.
    @StateObject private var graph: Owned<EpisodesScreenGraph>
    private let makeSection: (EpisodesScreenGraph) -> Content

    /// The search field's text, owned by the screen.
    ///
    /// `.searchable` needs a `Binding`, and the only two-way binding available
    /// without observation is local `@State`. It is a *write-only* mirror: the
    /// screen pushes each change into the view model and never reads anything
    /// back, so this stays consistent with the screen not observing the view
    /// model — the rows still arrive through the mapper.
    @State private var searchText = ""

    init(makeGraph: @escaping () -> EpisodesScreenGraph,
         makeSection: @escaping (EpisodesScreenGraph) -> Content) {
        _graph = StateObject(wrappedValue: Owned(makeGraph))
        self.makeSection = makeSection
    }

    var body: some View {
        NavigationStack {
            makeSection(graph.value)
                .navigationTitle("Episodes")
                .searchable(text: $searchText,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "Search episodes")
                // Episode titles are puns on proper nouns — "Rickshank
                // Rickdemption", "Mortynight Run" — so autocorrect turns a
                // correct query into a word the catalogue does not contain,
                // and capitalization only adds noise the match ignores.
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: searchText) { _, text in
                    // Straight through, with no debounce: the catalogue is
                    // already in memory, so a keystroke costs one pass through
                    // the mapper and no requests at all. See
                    // `EpisodesViewModel.updateSearchText(_:)`.
                    graph.value.viewModel.updateSearchText(text)
                }
                .toolbar {
                    // Debug only, and compiled out rather than hidden: a purge
                    // button has no business shipping, and `#if` is the one
                    // guard a release build cannot get wrong.
                    #if DEBUG
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await graph.value.viewModel.purgeCache() }
                        } label: {
                            Label("Purge cache", systemImage: "trash")
                        }
                    }
                    #endif
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
            return EpisodesScreenGraph(viewModel: viewModel,
                                       listMapper: EpisodesListSectionMapper(viewModel: viewModel))
        },
        makeSection: { graph in
            EpisodesListSectionView(viewModel: graph.viewModel, mapper: graph.listMapper)
        }
    )
}

/// Stubbed at the repository seam rather than the data-source one: the preview
/// wants canned domain models, and standing in for the repository skips the
/// cache, the network and the mapper in one substitution.
///
/// It serves three seasons rather than one so the sticky headers, the grouping
/// and the search across seasons are all reachable in the canvas without a
/// network. The episodes come back deliberately *unordered* within each season,
/// because putting them in order is the mapper's job and a preview that fed it
/// sorted input would never show whether it does it.
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
                                            image: URL(string: "https://rickandmortyapi.com/api/character/avatar/\(index).jpeg")!
                                        )
                                    })
            }
        }
    }

    func purgeCache() async throws {}
}
