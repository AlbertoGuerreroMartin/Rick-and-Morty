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
                Label("No characters found", systemImage: "magnifyingglass")
            } description: {
                Text(summary.map { "No results for \($0)." }
                     ?? "There are no characters to show.")
            } actions: {
                if canClearFilters {
                    Button("Clear filters", action: onClearFilters)
                        .buttonStyle(.borderedProminent)
                }
            }
        case .failed:
            ContentUnavailableView {
                Label("Couldn't load characters", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
