//
//  CharactersGridSectionView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Core
import DesignSystem
import SwiftUI

/// The same characters as the list, drawn two to a row as large square images.
struct CharactersGridSectionView: SectionViewContract {
    private static let columnCount = 2
    private static let spacing: CGFloat = 12
    private static let horizontalPadding: CGFloat = 16
    private static let cornerRadius: CGFloat = 16
    private static let fallbackCellWidth: CGFloat = 180

    @Environment(\.displayScale) private var displayScale

    let viewModel: any CharactersGridSectionViewModelContract

    let renderModelPublisher: AnyPublisher<CharactersGridRenderModel, Never>

    @State var renderModel: CharactersGridRenderModel = .hidden

    /// Measured once at the section level, or a wobbling decode size would fragment the image cache.
    @State private var sectionWidth: CGFloat = 0

    init(viewModel: any CharactersGridSectionViewModelContract,
         renderModelPublisher: AnyPublisher<CharactersGridRenderModel, Never>) {
        self.viewModel = viewModel
        self.renderModelPublisher = renderModelPublisher
    }

    private var cellWidth: CGFloat {
        guard sectionWidth > 0 else { return Self.fallbackCellWidth }
        let gutters = Self.horizontalPadding * 2 + Self.spacing * CGFloat(Self.columnCount - 1)
        return ((sectionWidth - gutters) / CGFloat(Self.columnCount)).rounded(.down)
    }

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

    @ViewBuilder
    func characterCell(character: CharacterModel, highlight: String?) -> some View {
        NavigationLink(value: CharactersRoute.detail(id: character.id)) {
            characterCellContent(character: character, highlight: highlight)
        }
        .buttonStyle(.plain)
    }

    /// A square `Color.clear` sets the cell size, so the image cannot propose its own.
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

    @ViewBuilder
    func characterInfo(character: CharacterModel, highlight: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(CharactersNameHighlighter.highlighted(character.name, matching: highlight))
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
                .accessibilityLabel(character.name)
            HStack(spacing: 5) {
                Circle()
                    .fill(character.status.color)
                    .frame(width: 7, height: 7)
                Text("\(character.status.displayName) · \(character.species)")
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
