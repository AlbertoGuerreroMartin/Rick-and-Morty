//
//  CharacterDetailHeaderSectionView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import DesignSystem
import SwiftUI

/// The picture, full width and square, with name and status over the bottom; or whatever the
/// screen has instead while there is nothing to show — a spinner, or the failure and its Retry.
struct CharacterDetailHeaderSectionView: View {
    /// Decode width before the section is measured; wide enough to avoid a soft first frame.
    private static let fallbackWidth: CGFloat = 390

    /// See `CharactersListSectionView.displayScale`.
    @Environment(\.displayScale) private var displayScale

    let viewModel: any CharacterDetailHeaderSectionViewModelContract

    private let renderModelPublisher: AnyPublisher<CharacterDetailHeaderRenderState, Never>

    @State var renderModel: CharacterDetailHeaderRenderState = .hidden

    /// Measured once: the image cache is keyed on decode size, and a value that changed between
    /// the spinner and the picture would decode the same avatar twice. See
    /// `CharactersGridSectionView.sectionWidth`.
    @State private var sectionWidth: CGFloat = 0

    init(viewModel: any CharacterDetailHeaderSectionViewModelContract,
         mapper: CharacterDetailHeaderSectionMapper) {
        self.viewModel = viewModel
        self.renderModelPublisher = mapper.renderModelPublisher()
    }

    private var width: CGFloat {
        sectionWidth > 0 ? sectionWidth : Self.fallbackWidth
    }

    /// Pixel size for the downsampler.
    private var imagePixelSize: CGFloat {
        width * displayScale
    }

    var body: some View {
        content
            // Full width before measurement, so the container is measured, not a transient state's own size.
            .frame(maxWidth: .infinity)
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
        case .visible(let header):
            image(header)
        case .failed:
            // No filter here: the reason is always `.failed`; `.noMatches` is unreachable.
            CharactersEmptyStateView(reason: .failed,
                                     onClearFilters: {},
                                     onRetry: { viewModel.retryLoad() })
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
        case .hidden:
            // Same size as the picture, so the info card pulled up over this edge doesn't jump when it arrives.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    ProgressView()
                }
        }
    }

    /// A square the image fills, not an image that sizes the square: height must not depend on
    /// whatever aspect ratio the API happened to serve.
    @ViewBuilder
    func image(_ header: CharacterDetailHeaderRenderModel) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                CachedAsyncImage(url: header.image, maxPixelSize: imagePixelSize) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
            }
            .overlay(alignment: .bottom) {
                title(header)
            }
            .clipped()
    }

    /// Name and status line, in white over a scrim; fixed to white regardless of color scheme
    /// since the backdrop is the image, not the screen.
    @ViewBuilder
    func title(_ header: CharacterDetailHeaderRenderModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header.name)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            HStack(spacing: 6) {
                Circle()
                    .fill(header.status.color)
                    .frame(width: 9, height: 9)
                Text("\(header.status.displayName) · \(header.species)")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Room for the info card, pulled up over this edge.
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 40, trailing: 16))
        .background {
            LinearGradient(colors: [.clear, .black.opacity(0.8)],
                           startPoint: .top,
                           endPoint: .bottom)
                .padding(.top, -80)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(header.name), \(header.status.displayName), \(header.species)")
    }
}
