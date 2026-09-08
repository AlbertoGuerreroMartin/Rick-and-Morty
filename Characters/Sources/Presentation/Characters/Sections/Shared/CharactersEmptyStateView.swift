//
//  CharactersEmptyStateView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import SwiftUI

/// Nothing to draw, and why. Shared by two sections with different view model contracts,
/// so the actions arrive as closures rather than a held contract.
struct CharactersEmptyStateView: View {
    let reason: CharactersSectionEmptyReason
    let onClearFilters: () -> Void
    let onRetry: () -> Void

    var body: some View {
        switch reason {
        case .noMatches(let summary, let canClearFilters):
            ContentUnavailableView {
                Label {
                    Text("No characters found", bundle: .module)
                } icon: {
                    Image(systemName: "magnifyingglass")
                }
            } description: {
                if let summary {
                    Text("No results for \(summary).", bundle: .module)
                } else {
                    Text("There are no characters to show.", bundle: .module)
                }
            } actions: {
                if canClearFilters {
                    Button(action: onClearFilters) {
                        Text("Clear filters", bundle: .module)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        case .failed:
            ContentUnavailableView {
                Label {
                    Text("Couldn't load characters", bundle: .module)
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
