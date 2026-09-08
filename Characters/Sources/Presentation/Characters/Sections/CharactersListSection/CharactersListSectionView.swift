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
    /// The avatar's rendered edge, in points.
    private static let avatarSize: CGFloat = 56

    /// The screen's pixels per point. Read from the SwiftUI environment rather
    /// than `UITraitCollection.current`: UIKit only populates the latter while
    /// it is calling into UIKit code (layout, drawing), so inside a SwiftUI body
    /// it can be the default trait collection whose scale is 0 — and a 0px
    /// decode target would turn every avatar into a 1px smear.
    @Environment(\.displayScale) private var displayScale

    /// The avatar edge in *pixels*, which is what the downsampler decodes to.
    /// Decoding at point size would be soft on every device shipped this decade;
    /// decoding at the source's own size would hold a full-resolution bitmap per
    /// row.
    private var avatarPixelSize: CGFloat {
        Self.avatarSize * displayScale
    }

    /// Held as the contract, not as a closure: "load the next page" is a
    /// capability of the view model the section is already bound to, and routing
    /// it through an escaping closure would hide that from the type system while
    /// adding a second thing to wire up in the factory and in every preview.
    ///
    /// This is *not* observation — the view never reads a property on it. The
    /// render pipeline is unchanged (publishers -> mapper -> `@State`); the view
    /// model is here only so the footer and the empty states have something to
    /// call.
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

    /// The footer is the last row of the `List`, which builds its rows lazily —
    /// see `CharactersPaginationFooterView` for why that is what makes it a
    /// pagination trigger, and why `List` rather than `onScrollVisibilityChange`.
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

    /// The row is a `NavigationLink` carrying a *value*, not a destination.
    ///
    /// The destination is built by the screen's `navigationDestination(for:)`,
    /// which means the detail is constructed when the push happens rather than
    /// once per visible row — a `NavigationLink(destination:)` would build a
    /// whole screen graph for every row the list lays out. It also keeps this
    /// section ignorant of what a character detail even is: it names a route
    /// value and nothing else.
    @ViewBuilder
    func characterRow(character: CharacterModel, highlight: String?) -> some View {
        NavigationLink(value: CharacterDetailRoute(id: character.id)) {
            characterRowContent(character: character, highlight: highlight)
        }
    }

    @ViewBuilder
    func characterRowContent(character: CharacterModel, highlight: String?) -> some View {
        HStack(spacing: 12) {
            // `CachedAsyncImage` rather than `AsyncImage`: it keeps the decoded
            // bitmap and the downloaded bytes, so a row scrolling back into view
            // draws immediately instead of flashing a placeholder and
            // re-decoding — and a relaunch costs no requests at all.
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
                    // The plain name, always: an `AttributedString` read aloud
                    // would announce nothing about the emphasis anyway, and the
                    // highlight is a visual aid to a sighted user scanning a
                    // list, not information.
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
