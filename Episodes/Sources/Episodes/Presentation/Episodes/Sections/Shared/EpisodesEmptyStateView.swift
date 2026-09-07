//
//  EpisodesEmptyStateView.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
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
struct EpisodesEmptyStateView: View {
    let reason: EpisodesSectionEmptyReason
    let onRetry: () -> Void

    var body: some View {
        switch reason {
        case .noMatches(let query):
            ContentUnavailableView {
                Label("No episodes found", systemImage: "magnifyingglass")
            } description: {
                // Quoting the text back is the difference between a dead end and
                // an explanation: with the whole catalogue on the device, what
                // was typed is the only reason nothing is showing.
                Text(query.map { "No results for \u{201C}\($0)\u{201D}." }
                     ?? "There are no episodes to show.")
            }
        case .failed:
            ContentUnavailableView {
                Label("Couldn't load episodes", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview("No matches") {
    EpisodesEmptyStateView(reason: .noMatches(query: "squanch"), onRetry: {})
}

#Preview("Failed") {
    EpisodesEmptyStateView(reason: .failed, onRetry: {})
}
