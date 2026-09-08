//
//  CharacterDetailEpisodesSectionView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import SwiftUI

/// Every episode the character appears in, under a heading.
///
/// A `LazyVStack` rather than a `List`: the whole screen is one `ScrollView`
/// with the header and the info card above this, and a `List` inside a
/// `ScrollView` would need a fixed height chosen by hand and would scroll
/// independently of everything above it. Lazy anyway, because a long-running
/// character appears in fifty episodes and there is no reason to build the rows
/// nobody has scrolled to.
struct CharacterDetailEpisodesSectionView: View {
    private static let horizontalPadding: CGFloat = 16

    private let renderModelPublisher: AnyPublisher<CharacterDetailEpisodesRenderModel, Never>

    @State var renderModel: CharacterDetailEpisodesRenderModel = .hidden

    /// No view model: like the info card, this section has nothing to call. The
    /// header owns the Retry, and the play buttons open a URL through the
    /// environment.
    init(mapper: CharacterDetailEpisodesSectionMapper) {
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
        case .visible(let episodes):
            episodesList(episodes)
        case .empty:
            section {
                Text("This character doesn't appear in any episode.")
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

    /// The heading and the padding, shared by both drawn states so the empty one
    /// sits exactly where the list would have.
    @ViewBuilder
    private func section<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Episodes")
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
