//
//  EpisodesListSectionView.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Core
import SwiftUI

struct EpisodesListSectionView: SectionViewContract {

    /// Not observed: only called for `retryLoad()`. Rows arrive through the mapper into `@State`.
    let viewModel: any EpisodesListSectionViewModelContract

    let renderModelPublisher: AnyPublisher<EpisodesListRenderModel, Never>

    @State var renderModel: EpisodesListRenderModel = .hidden

    init(viewModel: any EpisodesListSectionViewModelContract,
         renderModelPublisher: AnyPublisher<EpisodesListRenderModel, Never>) {
        self.viewModel = viewModel
        self.renderModelPublisher = renderModelPublisher
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
