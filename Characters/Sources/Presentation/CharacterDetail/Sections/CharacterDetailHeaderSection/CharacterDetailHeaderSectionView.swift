//
//  CharacterDetailHeaderSectionView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import DesignSystem
import SwiftUI

/// The picture, full width and square, with the character's name and status laid
/// over the bottom of it — and, while there is nothing to show, whatever the
/// screen has instead: a spinner, or the failure and its Retry.
struct CharacterDetailHeaderSectionView: View {
    /// Used for the decode size only, until the section has been measured. A
    /// device is at least this wide, so the fallback errs towards decoding
    /// *large* rather than towards a soft image on the first frame. It never
    /// sizes anything on screen: every state below takes the width it is
    /// proposed, so the layout is right on the first frame on any device.
    private static let fallbackWidth: CGFloat = 390

    /// See `CharactersListSectionView.displayScale` for why this comes from the
    /// environment and not from `UITraitCollection.current`.
    @Environment(\.displayScale) private var displayScale

    /// Held as the contract, not observed. Exactly as in the list and grid
    /// sections, the view model is here so the failure state has something to
    /// call — the render pipeline is still publishers -> mapper -> `@State`.
    let viewModel: any CharacterDetailHeaderSectionViewModelContract

    private let renderModelPublisher: AnyPublisher<CharacterDetailHeaderRenderState, Never>

    @State var renderModel: CharacterDetailHeaderRenderState = .hidden

    /// The section's width, measured once at the section level rather than per
    /// state. The image memory cache is keyed on the decode size, so a value
    /// that changed between the spinner and the picture would decode the same
    /// avatar twice. See `CharactersGridSectionView.sectionWidth`.
    @State private var sectionWidth: CGFloat = 0

    init(viewModel: any CharacterDetailHeaderSectionViewModelContract,
         mapper: CharacterDetailHeaderSectionMapper) {
        self.viewModel = viewModel
        self.renderModelPublisher = mapper.renderModelPublisher()
    }

    private var width: CGFloat {
        sectionWidth > 0 ? sectionWidth : Self.fallbackWidth
    }

    /// The image edge in *pixels*, which is what the downsampler decodes to.
    private var imagePixelSize: CGFloat {
        width * displayScale
    }

    var body: some View {
        content
            // The full width *before* the measurement, so what is measured is
            // the container and not whatever the current state happened to
            // draw: a spinner measured on its own would report its own size,
            // and the picture would then be decoded for a width nobody asked
            // for.
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
            // The shared empty state, wired to this screen's only escape. The
            // filter callback is a no-op because there is no filter here: the
            // reason is always `.failed`, and `.noMatches` is unreachable — a
            // character either loads or it does not.
            CharactersEmptyStateView(reason: .failed,
                                     onClearFilters: {},
                                     onRetry: { viewModel.retryLoad() })
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
        case .hidden:
            // A square the size of the picture that is coming, rather than a
            // spinner on its own: the info card is pulled up over the header's
            // bottom edge, so a header with no height would leave the card
            // overlapping the navigation bar and then jump down when the image
            // arrived. The same `Color.clear` square as the picture's, taking
            // the proposed width, so it is exactly as wide on every device and
            // nothing moves when the image replaces it.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    ProgressView()
                }
        }
    }

    /// A square the image fills, not an image that sizes the square.
    ///
    /// `Color.clear` with `aspectRatio(1)` and the picture in an overlay, for
    /// the same reason as the grid's cells: a `scaledToFill` image proposes its
    /// own size, and letting it drive layout makes the header's height depend on
    /// whatever the API happened to serve.
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

    /// The name and the status line, in white over a scrim.
    ///
    /// The scrim is a gradient from clear to translucent black rather than a
    /// solid bar, and it starts well above the text, so it reads as the bottom of
    /// the picture darkening instead of as a caption stuck on top. The colours
    /// are fixed to white on purpose and do not follow light or dark mode,
    /// because the backdrop is the image, not the screen — the same reasoning as
    /// the grid cell's.
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
                Text("\(header.status.rawValue.capitalized) · \(header.species)")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Room at the bottom for the info card, which is pulled up over this
        // edge: text sitting under it would be unreadable.
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 40, trailing: 16))
        .background {
            LinearGradient(colors: [.clear, .black.opacity(0.8)],
                           startPoint: .top,
                           endPoint: .bottom)
                .padding(.top, -80)
        }
        // One element: the picture says nothing, and the two lines are one fact
        // about the character rather than two things to swipe between.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(header.name), \(header.status.rawValue.capitalized), \(header.species)")
    }
}
