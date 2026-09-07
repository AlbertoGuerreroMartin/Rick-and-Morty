//
//  EpisodesListSectionView.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import SwiftUI

struct EpisodesListSectionView: View {

    /// Held as the contract, not as a closure: "retry the load" is a capability
    /// of the view model the section is already bound to, and routing it through
    /// an escaping closure would hide that from the type system while adding a
    /// second thing to wire up in the factory and in every preview.
    ///
    /// This is *not* observation — the view never reads a property on it. The
    /// render pipeline is unchanged (publishers -> mapper -> `@State`); the view
    /// model is here only so the empty state has something to call.
    let viewModel: any EpisodesListSectionViewModelContract

    private let renderModelPublisher: AnyPublisher<EpisodesListRenderModel, Never>

    @State var renderModel: EpisodesListRenderModel = .hidden

    init(viewModel: any EpisodesListSectionViewModelContract,
         mapper: EpisodesListSectionMapper) {
        self.viewModel = viewModel
        self.renderModelPublisher = mapper.renderModelPublisher()
    }

    var body: some View {
        content
            .onReceive(renderModelPublisher) {
                renderModel = $0
            }
    }

    @ViewBuilder
    var content: some View {
        switch renderModel {
        case .visible(let seasons):
            episodesList(seasons: seasons)
        case .empty(let reason):
            EpisodesEmptyStateView(reason: reason, onRetry: { viewModel.retryLoad() })
        case .hidden:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// A `List` of `Section`s rather than one flat list with separator rows: the
    /// season headers then stick to the top while scrolling, which is what makes
    /// a 51-row list navigable without a jump bar.
    @ViewBuilder
    func episodesList(seasons: [EpisodesSeasonRenderModel]) -> some View {
        List {
            ForEach(seasons) { season in
                Section {
                    ForEach(season.episodes) { episode in
                        EpisodeRowView(episode: episode)
                    }
                } header: {
                    Text(season.title)
                }
            }
        }
    }
}
