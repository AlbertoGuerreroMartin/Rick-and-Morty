//
//  LocationsCarouselSectionView.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine
import SwiftUI

/// The carousel, plus the two rules that make it a paginated screen rather than
/// a strip of circles: what a settled focus means, and where the next page is
/// asked for.
///
/// It is *stepped*: one location per snap, always centred, and whatever is
/// centred is what the card below describes. That is `.scrollTargetLayout()` and
/// `.scrollTargetBehavior(.viewAligned)` doing the snapping, a symmetric
/// `safeAreaPadding` making the aligned position the middle of the screen rather
/// than its leading edge, and `.scrollPosition(id:)` naming the item that
/// settled there. A free-scrolling row would have no such answer — the card
/// would need "the item nearest the centre", which is a different thing every
/// frame of a flick.
///
/// **The next page is asked for by the last item in the row**, not by this
/// section watching the focus. The row is a `LazyHStack`, so the pagination
/// item at its end only exists once the user has scrolled up to it — which is
/// exactly the signal "they have run out of loaded locations", the same way
/// the last row of the characters `List` is. See
/// `LocationsCarouselPaginationItemView`.
struct LocationsCarouselSectionView: View {
    private static let itemSpacing: CGFloat = 20

    /// What the edge inset is computed from until the section has been measured
    /// — one frame, on a phone-width screen.
    private static let fallbackWidth: CGFloat = 390

    /// Held as the contract, not as a closure: retrying a load, reporting a
    /// focus and asking for a page are all capabilities of the view model this
    /// section is already bound to, and routing three closures through the
    /// factory would hide that from the type system.
    ///
    /// This is *not* observation — the view never reads a property on it. The
    /// render pipeline is unchanged (publishers -> mapper -> `@State`).
    let viewModel: any LocationsCarouselSectionViewModelContract

    private let renderModelPublisher: AnyPublisher<LocationsCarouselRenderModel, Never>
    private let carouselMaxHeight: CGFloat = 200
    
    @State var renderModel: LocationsCarouselRenderModel = .hidden

    /// The item the carousel has settled on, written by the scroll view itself
    /// and by this section when something outside decides the selection.
    ///
    /// It is the section's own state rather than a value derived from the
    /// published selection, because `.scrollPosition(id:)` needs a *binding* it
    /// can write into as the user drags. The published id stays the source of
    /// truth: every change here is reported to the view model, and every change
    /// there is scrolled to below.
    ///
    /// It can also be the pagination item's id — the user can scroll onto the
    /// spinner — which is not a location and selects nothing; see
    /// `claimFocusIfNeeded` for what happens when the page it was waiting for
    /// lands.
    @State private var position: String?

    /// The section's width, measured so the first and last circles can reach the
    /// centre of the screen. A carousel with no horizontal inset can only put
    /// its first item at the leading edge, which would leave location number one
    /// — the one selected on a cold start — off to the side of the card
    /// describing it.
    @State private var sectionWidth: CGFloat = 0

    init(viewModel: any LocationsCarouselSectionViewModelContract,
         mapper: LocationsCarouselSectionMapper) {
        self.viewModel = viewModel
        self.renderModelPublisher = mapper.renderModelPublisher()
    }

    /// Half the leftover width, which is what turns "aligned to the leading edge
    /// of the visible region" into "centred on the screen".
    private var edgeInset: CGFloat {
        let width = sectionWidth > 0 ? sectionWidth : Self.fallbackWidth
        return max(0, (width - LocationsCarouselItemView.diameter) / 2)
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            // `.background` rather than a fixed colour, and rather than the
            // helix's near-black gradient: the carousel is a band of the screen
            // now, not a scene, so it should be the same surface as the card
            // under it in whichever appearance the user is in.
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
                // The height the carousel will take once it arrives, so the card
                // below does not jump up the screen and back down again when the
                // first page lands.
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
                        // Tapping moves the focus, and the focus is what
                        // selects — so this does not call the view model at
                        // all. One path in, whether the user dragged or
                        // tapped.
                        .onTapGesture {
                            withAnimation(.snappy) { position = item.id }
                        }
                    }
                    
                    // The last stop, and the pagination trigger — see the type. It
                    // sits inside the lazy row on purpose: outside it, it would be
                    // built on the first frame and chain-load every page.
                    LocationsCarouselPaginationItemView(footer: footer, loadedCount: items.count) {
                        await viewModel.loadNextPage()
                    }
                    .scrollTransition(.interactive, axis: .horizontal, transition: Self.scrollTransition)
                    .id(LocationsCarouselPaginationItemView.id)
                }
                // Outermost on the stack, so the scroll view is in no doubt
                // about which layout holds its snap targets.
                .scrollTargetLayout()
            }
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .safeAreaPadding(.horizontal, edgeInset)
        .scrollPosition(id: $position, anchor: .center)
        .frame(maxHeight : carouselMaxHeight)
        .onChange(of: position) { _, id in
            focusChanged(to: id, items: items)
        }
        // The selection decided somewhere else — page 1 auto-selecting, a reload
        // choosing a new first location. `initial: true` so a carousel built
        // with a selection already in hand scrolls to it rather than opening on
        // item one.
        .onChange(of: selectedId, initial: true) { _, id in
            moveFocus(to: id, items: items)
        }
        // The carousel always has something at its centre, so the screen is told
        // what that is without waiting for a gesture the user has no reason to
        // make — otherwise the card below would sit blank under a circle they
        // are already looking at. Also the repair for a list that came back
        // shorter, or came back different, than the one `position` was pointing
        // into, and for a page landing under a centred spinner.
        .onChange(of: items.map(\.id), initial: true) { previous, ids in
            claimFocusIfNeeded(previous: previous, ids: ids, selectedId: selectedId)
        }
    }

    /// Driven by the scroll rather than by the settled focus, so an item grows
    /// as it comes in instead of popping when the snap finishes. `.interactive`
    /// and `phase.value` rather than `phase.isIdentity`: the value is a
    /// continuous -1...1 across the container, which is what makes the growing
    /// track the finger instead of animating after it.
    ///
    /// `nonisolated` because `scrollTransition` wants a `@Sendable` function and
    /// a `View`'s statics inherit its main-actor isolation; this is pure
    /// arithmetic on the phase and touches nothing of the view's.
    private nonisolated static func scrollTransition(_ view: EmptyVisualEffect,
                                                     _ phase: ScrollTransitionPhase) -> some VisualEffect {
        view
            .scaleEffect(1 - 0.15 * abs(phase.value))
            .opacity(1 - 0.4 * abs(phase.value))
    }

    // MARK: - Focus

    /// An item settled at the centre: it *is* the selection.
    ///
    /// The pagination item settles here too when the user scrolls onto it, and
    /// selects nothing — it is not a location, and the guard is what keeps the
    /// card describing the last real one meanwhile.
    private func focusChanged(to id: String?, items: [LocationsCarouselItemRenderModel]) {
        guard let id, items.contains(where: { $0.id == id }) else { return }
        viewModel.selectLocation(id: id)
    }

    /// Scrolls to a selection this section did not make.
    ///
    /// Guarded on equality, because the common case is this view's *own* focus
    /// change coming back round through the view model: the carousel is already
    /// there, and writing the position again would restart a scroll that has
    /// just finished.
    private func moveFocus(to id: String?, items: [LocationsCarouselItemRenderModel]) {
        guard let id, id != position, items.contains(where: { $0.id == id }) else { return }
        position = id
    }

    /// Centres something when nothing is centred, or when what was centred is
    /// gone. Never moves a focus that is still valid: a page landing while the
    /// user is halfway through the catalogue must not send them back to the top.
    ///
    /// The one focus that *is* moved is the spinner's. A user who scrolled onto
    /// the pagination item is waiting for the page it stands for, so when that
    /// page lands the carousel steps onto its first location — the spinner
    /// turns into the thing it promised — rather than staying put and asking
    /// for the page after it, which would chain-load the rest of the catalogue
    /// under a user who is not scrolling.
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
