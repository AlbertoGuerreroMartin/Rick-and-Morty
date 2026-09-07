//
//  CharactersEmptyStateView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import SwiftUI

/// Nothing to draw, and why.
///
/// `ContentUnavailableView` rather than a hand-rolled `VStack` so the copy gets
/// the system's own layout, metrics and Dynamic Type behaviour for free — and
/// so this state looks like every other "nothing here" in iOS rather than like
/// something this app invented.
///
/// The actions arrive as closures because this is a leaf shared by two sections
/// with two different view model contracts; each section still holds its own
/// contract and hands the calls down from there.
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
                // Naming the query is the difference between a dead end and an
                // explanation the user can act on: a forgotten species filter is
                // invisible until the copy says it is there.
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
