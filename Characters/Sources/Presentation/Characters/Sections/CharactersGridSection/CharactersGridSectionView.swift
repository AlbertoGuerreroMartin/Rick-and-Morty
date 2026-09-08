//
//  CharactersGridSectionView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import DesignSystem
import SwiftUI

/// The same characters as the list, drawn two to a row as large square images
/// with the text laid over the bottom of each one.
struct CharactersGridSectionView: View {
    /// Two on every device: "huge image" is the point of this layout, and a
    /// third column on an iPad would trade that for density the list already
    /// offers.
    private static let columnCount = 2
    private static let spacing: CGFloat = 12
    private static let horizontalPadding: CGFloat = 16
    private static let cornerRadius: CGFloat = 16
    /// Used for the decode size only until the section has been measured. The
    /// avatars the API serves are 300px on a side, so at any plausible scale
    /// this decodes at source resolution, same as the measured value would.
    private static let fallbackCellWidth: CGFloat = 180

    /// See `CharactersListSectionView.displayScale` for why this comes from the
    /// environment and not from `UITraitCollection.current`.
    @Environment(\.displayScale) private var displayScale

    /// Held as the contract, not observed. Exactly as in the list section, the
    /// view model is here so the footer and the empty states have something to
    /// call — the render pipeline is still publishers -> mapper -> `@State`.
    let viewModel: any CharactersGridSectionViewModelContract

    private let renderModelPublisher: AnyPublisher<CharactersGridRenderModel, Never>

    @State var renderModel: CharactersGridRenderModel = .hidden

    /// The section's width, measured once at the section level rather than per
    /// cell. The image memory cache is keyed on the decode size, so a value that
    /// wobbled from cell to cell would fragment it into near-duplicate bitmaps
    /// and re-decode on every wobble. Measured on the whole section — which is
    /// on screen from the very first spinner — it is already known by the time
    /// the first cell exists, and only changes with the container.
    @State private var sectionWidth: CGFloat = 0

    init(viewModel: any CharactersGridSectionViewModelContract,
         mapper: CharactersGridSectionMapper) {
        self.viewModel = viewModel
        self.renderModelPublisher = mapper.renderModelPublisher()
    }

    private var cellWidth: CGFloat {
        guard sectionWidth > 0 else { return Self.fallbackCellWidth }
        let gutters = Self.horizontalPadding * 2 + Self.spacing * CGFloat(Self.columnCount - 1)
        return ((sectionWidth - gutters) / CGFloat(Self.columnCount)).rounded(.down)
    }

    /// The cell edge in *pixels*, which is what the downsampler decodes to.
    private var cellPixelSize: CGFloat {
        cellWidth * displayScale
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Self.spacing), count: Self.columnCount)
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                sectionWidth = width
            }
            .onReceive(renderModelPublisher) {
                renderModel = $0
            }
    }

    @ViewBuilder
    var content: some View {
        switch renderModel {
        case .visible(let characters, let footer, let highlight):
            charactersGrid(characters: characters, footer: footer, highlight: highlight)
        case .empty(let reason):
            CharactersEmptyStateView(reason: reason,
                                     onClearFilters: { viewModel.clearAllFilters() },
                                     onRetry: { viewModel.retryLoad() })
        case .hidden:
            ProgressView()
        }
    }

    /// A `LazyVStack` around the grid *and* the footer, not a `LazyVGrid`
    /// alone: the grid is lazy about its cells, but anything placed after it in
    /// a plain `ScrollView` is built on the first frame. Inside the `LazyVStack`
    /// the footer is a lazy child like any other, so its `.task` fires when the
    /// user reaches it — the same contract the `List` gives the list section.
    @ViewBuilder
    func charactersGrid(characters: [CharacterModel],
                        footer: CharactersSectionFooter,
                        highlight: String?) -> some View {
        ScrollView {
            LazyVStack(spacing: Self.spacing) {
                LazyVGrid(columns: columns, spacing: Self.spacing) {
                    ForEach(characters, id: \.id) { character in
                        characterCell(character: character, highlight: highlight)
                            .accessibilityElement(children: .combine)
                    }
                }
                CharactersPaginationFooterView(footer: footer, loadedCount: characters.count) {
                    await viewModel.loadNextPage()
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, Self.spacing)
        }
    }

    /// A square image with the row's three lines of text over its bottom edge.
    ///
    /// The image sits in an `overlay` of a square `Color.clear` rather than
    /// being the cell itself: a `scaledToFill` image proposes its own size, and
    /// letting it drive the layout is how a grid ends up with cells of uneven
    /// heights. The clear square sets the size; the image fills it and is
    /// clipped.
    ///
    /// Wrapped in a `NavigationLink` carrying a *value* rather than a
    /// destination, for the same reasons as the list's row — the detail is built
    /// on the push, not once per visible cell, and this section never learns
    /// what it is pushing. `.buttonStyle(.plain)` is not cosmetic here: the
    /// default style tints its label with the accent colour, which on a cell
    /// that *is* a photograph turns every character blue.
    @ViewBuilder
    func characterCell(character: CharacterModel, highlight: String?) -> some View {
        NavigationLink(value: CharacterDetailRoute(id: character.id)) {
            characterCellContent(character: character, highlight: highlight)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func characterCellContent(character: CharacterModel, highlight: String?) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                CachedAsyncImage(url: character.image, maxPixelSize: cellPixelSize) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
            }
            .overlay(alignment: .bottom) {
                characterInfo(character: character, highlight: highlight)
            }
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }

    /// The same three lines as the list row, in white over a scrim.
    ///
    /// The scrim is a gradient from clear to translucent black rather than a
    /// solid bar, and it starts above the text rather than at its edge, so it
    /// reads as the bottom of the picture darkening instead of as a caption
    /// strip stuck on top. It is what keeps the text legible on a white lab
    /// coat and on a black void alike; the colours are fixed to white on purpose
    /// and do not follow light or dark mode, because the backdrop is the image,
    /// not the screen.
    @ViewBuilder
    func characterInfo(character: CharacterModel, highlight: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(CharactersNameHighlighter.highlighted(character.name, matching: highlight))
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
                // The plain name, always: the highlight is a visual aid to a
                // sighted user scanning the grid, not information.
                .accessibilityLabel(character.name)
            HStack(spacing: 5) {
                Circle()
                    .fill(character.status.color)
                    .frame(width: 7, height: 7)
                Text("\(character.status.rawValue.capitalized) · \(character.species)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            let dimension = character.location.dimension.flatMap { "(\($0))" } ?? ""
            Text("\(character.location.name) \(dimension)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background {
            LinearGradient(colors: [.clear, .black.opacity(0.75)],
                           startPoint: .top,
                           endPoint: .bottom)
                .padding(.top, -48)
        }
    }
}
