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
            emptyState(reason: reason)
        case .hidden:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    func charactersList(characters: [CharacterModel],
                        footer: CharactersListFooter,
                        highlight: String?) -> some View {
        List {
            ForEach(characters, id: \.id) { character in
                characterRow(character: character, highlight: highlight)
                    .accessibilityElement(children: .combine)
            }
            footerRow(footer: footer, loadedCount: characters.count)
                .accessibilityElement(children: .combine)
        }
    }

    /// Nothing to draw, and why.
    ///
    /// `ContentUnavailableView` rather than a hand-rolled `VStack` so the copy
    /// gets the system's own layout, metrics and Dynamic Type behaviour for
    /// free — and so this state looks like every other "nothing here" in iOS
    /// rather than like something this app invented.
    @ViewBuilder
    func emptyState(reason: CharactersListEmptyReason) -> some View {
        switch reason {
        case .noMatches(let summary, let canClearFilters):
            ContentUnavailableView {
                Label("No characters found", systemImage: "magnifyingglass")
            } description: {
                // Naming the query is the difference between a dead end and an
                // explanation the user can act on: a forgotten species filter is
                // invisible until the copy says it is there.
                Text(summary.map { "No results for \($0)." }
                     ?? "There are no characters to show.")
            } actions: {
                if canClearFilters {
                    Button("Clear filters") {
                        viewModel.clearAllFilters()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        case .failed:
            ContentUnavailableView {
                Label("Couldn't load characters", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Retry") {
                    viewModel.retryLoad()
                }
                .buttonStyle(.borderedProminent)
            }
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
    func characterRow(character: CharacterModel, highlight: String?) -> some View {
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
                Text(highlighted(character.name, matching: highlight))
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

    /// The searched substring, emphasised inside the name.
    ///
    /// Matched case- and diacritic-insensitively so it lines up with what the
    /// server matched. A name that does not contain the text is returned plain
    /// rather than treated as an error: the server may well have matched on
    /// something this client cannot see.
    private func highlighted(_ name: String, matching highlight: String?) -> AttributedString {
        var attributed = AttributedString(name)
        guard let highlight = CharactersFilter.normalized(highlight),
              let matched = name.range(of: highlight, options: [.caseInsensitive, .diacriticInsensitive]),
              let range = Range(matched, in: attributed) else {
            return attributed
        }

        attributed[range].font = .headline.bold()
        attributed[range].foregroundColor = .accentColor
        return attributed
    }
}
