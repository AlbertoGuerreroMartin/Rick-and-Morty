//
//  LocationsEmptyStateView.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import SwiftUI

/// Nothing to draw, and why.
///
/// `ContentUnavailableView` rather than a hand-rolled `VStack` so the copy gets
/// the system's own layout, metrics and Dynamic Type behaviour for free — and so
/// this state looks like every other "nothing here" in iOS rather than like
/// something this app invented.
///
/// The retry arrives as a closure because this is a leaf: it draws a reason and
/// nothing else, and the section that owns a view model is the one that knows
/// what retrying means.
struct LocationsEmptyStateView: View {
    let reason: LocationsSectionEmptyReason
    let onRetry: () -> Void

    var body: some View {
        switch reason {
        case .noLocations:
            ContentUnavailableView {
                Label("No locations", systemImage: "mappin.slash")
            } description: {
                // No Retry here: the API answered, and it answered correctly.
                // A button that re-asked a question already answered would
                // suggest the user did something wrong.
                Text("There are no locations to show.")
            }
        case .failed:
            ContentUnavailableView {
                Label("Couldn't load locations", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview("No locations") {
    LocationsEmptyStateView(reason: .noLocations, onRetry: {})
}

#Preview("Failed") {
    LocationsEmptyStateView(reason: .failed, onRetry: {})
}
