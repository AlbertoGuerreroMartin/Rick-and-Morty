//
//  LocationsCarouselSectionView.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine
import SwiftUI

/// The carousel: one location per snap, always centred (`.scrollTargetLayout()` +
/// `.viewAligned` + symmetric `safeAreaPadding`), with `.scrollPosition(id:)` naming
/// whatever settled there. The next page is triggered by the last row item becoming
/// visible in the lazy `LazyHStack`, not by this section watching the focus.
struct LocationsCarouselSectionView: View {
    private static let itemSpacing: CGFloat = 20

    /// Used for the edge inset until the section is measured (one frame, on a phone-width screen).
    private static let fallbackWidth: CGFloat = 390

    /// Held as the contract, not a closure, so retry/focus/pagination stay typed capabilities.
    /// Not observed: the render pipeline is still publishers -> mapper -> `@State`.
    let viewModel: any LocationsCarouselSectionViewModelContract

    private let renderModelPublisher: AnyPublisher<LocationsCarouselRenderModel, Never>
    private let carouselMaxHeight: CGFloat = 200

    @State var renderModel: LocationsCarouselRenderModel = .hidden

    /// The settled item. Section-owned, not derived, because `.scrollPosition(id:)` needs a
    /// binding it can write as the user drags; the published id stays the source of truth.
    /// Can also be the pagination item's id — see `claimFocusIfNeeded`.
    @State private var position: String?

    /// Measured so the first/last circles can reach screen centre instead of the leading edge.
    @State private var sectionWidth: CGFloat = 0

    init(viewModel: any LocationsCarouselSectionViewModelContract,
         mapper: LocationsCarouselSectionMapper) {
        self.viewModel = viewModel
        self.renderModelPublisher = mapper.renderModelPublisher()
    }

    private var edgeInset: CGFloat {
        let width = sectionWidth > 0 ? sectionWidth : Self.fallbackWidth
        return max(0, (width - LocationsCarouselItemView.diameter) / 2)
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background(.background)
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
        case .visible(let items, let selectedId, let footer):
            carousel(items: items, selectedId: selectedId, footer: footer)
        case .empty(let reason):
            LocationsEmptyStateView(reason: reason, onRetry: { viewModel.retryLoad() })
        case .hidden:
            ProgressView()
                // Reserves the carousel's eventual height so the card below doesn't jump.
                .frame(height: carouselMaxHeight)
        }
    }

    @ViewBuilder
    func carousel(items: [LocationsCarouselItemRenderModel],
                  selectedId: String?,
                  footer: LocationsSectionFooter) -> some View {
        ScrollView(.horizontal) {
            VStack(spacing: 0) {
                LazyHStack(spacing: Self.itemSpacing) {
                    ForEach(items) { item in
                        LocationsCarouselItemView(title: item.title,
                                                  isFocused: item.id == position)
                        .scrollTransition(.interactive, axis: .horizontal, transition: Self.scrollTransition)
                        .id(item.id)
                        // Only moves the focus; the focus itself is what selects, one path for tap or drag.
                        .onTapGesture {
                            withAnimation(.snappy) { position = item.id }
                        }
                    }

                    LocationsCarouselPaginationItemView(footer: footer, loadedCount: items.count) {
                        await viewModel.loadNextPage()
                    }
                    .scrollTransition(.interactive, axis: .horizontal, transition: Self.scrollTransition)
                    .id(LocationsCarouselPaginationItemView.id)
                }
                .scrollTargetLayout()
            }
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .safeAreaPadding(.horizontal, edgeInset)
        .scrollPosition(id: $position, anchor: .center)
        .frame(maxHeight: carouselMaxHeight)
        .onChange(of: position) { _, id in
            focusChanged(to: id, items: items)
        }
        // `initial: true` so a carousel built with a selection already in hand scrolls to it.
        .onChange(of: selectedId, initial: true) { _, id in
            moveFocus(to: id, items: items)
        }
        .onChange(of: items.map(\.id), initial: true) { previous, ids in
            claimFocusIfNeeded(previous: previous, ids: ids, selectedId: selectedId)
        }
    }

    /// `nonisolated`: `scrollTransition` needs `@Sendable`, and this touches nothing of the view's.
    private nonisolated static func scrollTransition(_ view: EmptyVisualEffect,
                                                     _ phase: ScrollTransitionPhase) -> some VisualEffect {
        view
            .scaleEffect(1 - 0.15 * abs(phase.value))
            .opacity(1 - 0.4 * abs(phase.value))
    }

    // MARK: - Focus

    /// The pagination item can settle here too; the guard keeps the card on the last real location.
    private func focusChanged(to id: String?, items: [LocationsCarouselItemRenderModel]) {
        guard let id, items.contains(where: { $0.id == id }) else { return }
        viewModel.selectLocation(id: id)
    }

    /// Guarded on equality: the common case is this view's own focus change echoing back
    /// through the view model, and rewriting it would restart a scroll that just finished.
    private func moveFocus(to id: String?, items: [LocationsCarouselItemRenderModel]) {
        guard let id, id != position, items.contains(where: { $0.id == id }) else { return }
        position = id
    }

    /// Re-centres only when the current focus is gone (a page landing must not reset a valid
    /// one). The one exception: a focus parked on the spinner steps onto the newly loaded page's
    /// first location instead of chain-loading the next one.
    private func claimFocusIfNeeded(previous: [String], ids: [String], selectedId: String?) {
        if position == LocationsCarouselPaginationItemView.id {
            let known = Set(previous)
            if let first = ids.first(where: { !known.contains($0) }) {
                position = first
            }
            return
        }
        if let position, ids.contains(position) { return }
        position = selectedId.flatMap { ids.contains($0) ? $0 : nil } ?? ids.first
    }
}
