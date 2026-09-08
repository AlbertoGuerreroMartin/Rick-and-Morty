//
//  CharacterDetailEpisodesSectionView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Core
import SwiftUI

/// Every episode the character appears in, under a heading. `LazyVStack`, not `List`: the
/// whole screen is one `ScrollView`, and a nested `List` would need a fixed height and
/// scroll independently.
struct CharacterDetailEpisodesSectionView: SectionViewContract {
    private static let horizontalPadding: CGFloat = 16

    /// Held to satisfy `SectionViewContract`; nothing is called on it. The header owns the Retry.
    let viewModel: any CharacterDetailEpisodesSectionViewModelContract

    let renderModelPublisher: AnyPublisher<CharacterDetailEpisodesRenderModel, Never>

    @State var renderModel: CharacterDetailEpisodesRenderModel = .hidden

    init(viewModel: any CharacterDetailEpisodesSectionViewModelContract,
         renderModelPublisher: AnyPublisher<CharacterDetailEpisodesRenderModel, Never>) {
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
        case .visible(let episodes):
            episodesList(episodes)
        case .empty:
            section {
                Text("This character doesn't appear in any episode.", bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        case .hidden:
            EmptyView()
        }
    }

    @ViewBuilder
    func episodesList(_ episodes: [CharacterDetailEpisodeModel]) -> some View {
        section {
            LazyVStack(spacing: 0) {
                ForEach(Array(episodes.enumerated()), id: \.element.id) { index, episode in
                    if index > 0 {
                        Divider()
                    }
                    CharacterDetailEpisodeRowView(episode: episode)
                }
            }
        }
    }

    /// Shared by both drawn states so the empty one sits exactly where the list would have.
    @ViewBuilder
    private func section<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Episodes", bundle: .module)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }
}
