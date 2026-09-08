//
//  LocationsEmptyStateView.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import SwiftUI

/// Nothing to draw, and why. `onRetry` is a closure because this is a leaf view with no view model.
struct LocationsEmptyStateView: View {
    let reason: LocationsSectionEmptyReason
    let onRetry: () -> Void

    var body: some View {
        switch reason {
        case .noLocations:
            ContentUnavailableView {
                Label("No locations", systemImage: "mappin.slash")
            } description: {
                // No Retry: the API answered correctly, there's just nothing to show.
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
