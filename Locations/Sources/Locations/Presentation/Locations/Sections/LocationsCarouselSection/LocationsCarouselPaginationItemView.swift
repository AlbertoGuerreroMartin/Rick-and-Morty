//
//  LocationsCarouselPaginationItemView.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import SwiftUI

/// The last stop on the carousel *is* the pagination trigger.
///
/// This is `CharactersPaginationFooterView` turned on its side. It only works
/// inside a lazy container — here the carousel's `LazyHStack` — which builds its
/// children as they approach the visible region, so this view is only
/// instantiated, and its `.task` only runs, when the user has scrolled to the
/// end of what is loaded. That replaces the "is the focus within N items of the
/// end?" arithmetic with the framework's own laziness, exactly as the list and
/// grid on the characters screen do. Drawn as a plain footer under the carousel
/// it would be on screen from the first frame and either chain-load every page
/// or spin forever over nothing, which is why it is an item in the row instead.
///
/// `id: loadedCount` re-fires the task when a page lands while this item is
/// still on screen — a short page, or a user who scrolled onto the spinner
/// itself — instead of leaving it sitting there waiting for a scroll that never
/// comes. `.loadMore` and `.loading` are one branch on purpose: separate
/// branches would give SwiftUI two identities and cancel the very task that
/// moved the state from one to the other.
///
/// It is an empty circle, the same yellow sphere as every other stop, so the
/// end of the loaded catalogue reads as "one more coming" rather than as a
/// different kind of thing appearing in the row.
struct LocationsCarouselPaginationItemView: View {

    /// The scroll position id of this item. Never a location's id, so the
    /// section can tell "the spinner is centred" from "a location is centred".
    static let id = "locations-carousel-pagination"

    let footer: LocationsSectionFooter
    let loadedCount: Int
    let loadNextPage: () async -> Void

    var body: some View {
        switch footer {
        case .loadMore, .loading:
            circle {
                ProgressView()
                    .tint(.black.opacity(0.6))
                    .scaleEffect(1.4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading more locations")
            .task(id: loadedCount) {
                await loadNextPage()
            }
        case .retry:
            circle {
                VStack(spacing: 8) {
                    Text("Couldn't load more")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.black.opacity(0.78))
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadNextPage() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.black)
                    .controlSize(.small)
                }
                .padding(.horizontal, LocationsCarouselItemView.diameter * 0.12)
            }
        case .none:
            EmptyView()
        }
    }

    private func circle<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            LocationsCarouselCircleView(isFocused: false)
            content()
        }
        // Same reason as `LocationsCarouselItemView`: the frame on the stack is
        // what makes the retry copy wrap inside the circle.
        .frame(width: LocationsCarouselItemView.diameter, height: LocationsCarouselItemView.diameter)
    }
}

#Preview("Loading") {
    LocationsCarouselPaginationItemView(footer: .loading, loadedCount: 20, loadNextPage: {})
        .padding(40)
}

#Preview("Retry") {
    LocationsCarouselPaginationItemView(footer: .retry, loadedCount: 20, loadNextPage: {})
        .padding(40)
}
