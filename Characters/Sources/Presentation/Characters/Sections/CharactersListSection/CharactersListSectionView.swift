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
    /// model is here only so the footer has something to call.
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
        case .visible(let characters, let footer):
            charactersList(characters: characters, footer: footer)
        case .hidden:
            ProgressView()
        }
    }

    @ViewBuilder
    func charactersList(characters: [CharacterModel], footer: CharactersListFooter) -> some View {
        List {
            ForEach(characters, id: \.id) { character in
                characterRow(character: character)
                    .accessibilityElement(children: .combine)
            }
            footerRow(footer: footer, loadedCount: characters.count)
                .accessibilityElement(children: .combine)
        }
    }

    /// The last row of the list *is* the trigger.
    ///
    /// `List` builds its rows lazily, so this one is only instantiated — and its
    /// `.task` only runs — when the user has actually scrolled to the bottom.
    /// That replaces the usual "is row N - 5 visible?" geometry maths with the
    /// framework's own laziness, and it does not depend on
    /// `onScrollVisibilityChange`, which `List` does not report reliably.
    ///
    /// `id: loadedCount` re-fires the task when a page lands while the footer is
    /// still on screen — a short page, or a tall device — instead of leaving a
    /// spinner sitting there forever waiting for a scroll that never comes.
    @ViewBuilder
    func footerRow(footer: CharactersListFooter, loadedCount: Int) -> some View {
        switch footer {
        case .loadMore, .loading:
            // One branch for both, deliberately: SwiftUI would otherwise give
            // the two states different identities and cancel the very task that
            // moved `.loadMore` to `.loading`.
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .task(id: loadedCount) {
                    await viewModel.loadNextPage()
                }
        case .retry:
            VStack(spacing: 8) {
                Text("Couldn't load more characters")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await viewModel.loadNextPage() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    func characterRow(character: CharacterModel) -> some View {
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
                Text(character.name)
                    .font(.headline)
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
