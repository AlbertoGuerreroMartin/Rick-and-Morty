//
//  CharactersListSectionView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine
import DesignSystem
import SwiftUI

struct CharactersListSectionView: View {
    private static let avatarSize: CGFloat = 56

    /// Read from the environment, not `UITraitCollection.current`, which can report scale 0
    /// outside UIKit's own layout/drawing calls, decoding avatars down to a 1px smear.
    @Environment(\.displayScale) private var displayScale

    /// Pixel size for the downsampler.
    private var avatarPixelSize: CGFloat {
        Self.avatarSize * displayScale
    }

    let viewModel: any CharactersListSectionViewModelContract

    private let renderModelPublisher: AnyPublisher<CharactersListRenderModel, Never>

    @State var renderModel: CharactersListRenderModel = .hidden

    init(viewModel: any CharactersListSectionViewModelContract,
         mapper: CharactersListSectionMapper) {
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
        case .visible(let characters, let footer, let highlight):
            charactersList(characters: characters, footer: footer, highlight: highlight)
        case .empty(let reason):
            CharactersEmptyStateView(reason: reason,
                                     onClearFilters: { viewModel.clearAllFilters() },
                                     onRetry: { viewModel.retryLoad() })
        case .hidden:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Footer is the `List`'s last row. See `CharactersPaginationFooterView` for why `List`
    /// over `onScrollVisibilityChange`.
    @ViewBuilder
    func charactersList(characters: [CharacterModel],
                        footer: CharactersSectionFooter,
                        highlight: String?) -> some View {
        List {
            ForEach(characters, id: \.id) { character in
                characterRow(character: character, highlight: highlight)
                    .accessibilityElement(children: .combine)
            }
            CharactersPaginationFooterView(footer: footer, loadedCount: characters.count) {
                await viewModel.loadNextPage()
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// Value-based `NavigationLink`: the destination is built by the screen's
    /// `navigationDestination(for:)`, not once per visible row.
    @ViewBuilder
    func characterRow(character: CharacterModel, highlight: String?) -> some View {
        NavigationLink(value: CharactersRoute.detail(id: character.id)) {
            characterRowContent(character: character, highlight: highlight)
        }
    }

    @ViewBuilder
    func characterRowContent(character: CharacterModel, highlight: String?) -> some View {
        HStack(spacing: 12) {
            // Keeps the decoded bitmap and bytes, so a row scrolling back or a relaunch doesn't re-decode.
            CachedAsyncImage(url: character.image, maxPixelSize: avatarPixelSize) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .frame(width: Self.avatarSize, height: Self.avatarSize)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(CharactersNameHighlighter.highlighted(character.name, matching: highlight))
                    .font(.headline)
                    // Plain name: the highlight is a visual aid, not information VoiceOver needs.
                    .accessibilityLabel(character.name)
                HStack(spacing: 5) {
                    Circle()
                        .fill(character.status.color)
                        .frame(width: 7, height: 7)
                    Text("\(character.status.rawValue.capitalized) · \(character.species)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                let dimension = character.location.dimension.flatMap { "(\($0))" } ?? ""
                Text("\(character.location.name) \(dimension)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
