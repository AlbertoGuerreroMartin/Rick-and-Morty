//
//  LocationsCarouselPaginationItemView.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import SwiftUI

/// The last stop on the carousel is the pagination trigger: an item in the lazy `LazyHStack`,
/// so it's instantiated (and its `.task` runs) only once scrolled into view. `id: loadedCount`
/// re-fires the task if a page lands while it's still on screen. `.loadMore` and `.loading`
/// share one branch so SwiftUI doesn't cancel the task by treating them as different identities.
struct LocationsCarouselPaginationItemView: View {

    /// Never a location's id, so the section can tell the spinner apart from a real location.
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
            .accessibilityLabel(Text("Loading more locations", bundle: .module))
            .task(id: loadedCount) {
                await loadNextPage()
            }
        case .retry:
            circle {
                VStack(spacing: 8) {
                    Text("Couldn't load more locations", bundle: .module)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.black.opacity(0.78))
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await loadNextPage() }
                    } label: {
                        Text("Retry", bundle: .module)
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
