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
                Label {
                    Text("No locations", bundle: .module)
                } icon: {
                    Image(systemName: "mappin.slash")
                }
            } description: {
                // No Retry: the API answered correctly, there's just nothing to show.
                Text("There are no locations to show.", bundle: .module)
            }
        case .failed:
            ContentUnavailableView {
                Label {
                    Text("Couldn't load locations", bundle: .module)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
            } description: {
                Text("Check your connection and try again.", bundle: .module)
            } actions: {
                Button(action: onRetry) {
                    Text("Retry", bundle: .module)
                }
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
