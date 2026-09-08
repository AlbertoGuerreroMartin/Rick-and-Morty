//
//  EpisodesEmptyStateView.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import SwiftUI

struct EpisodesEmptyStateView: View {
    let reason: EpisodesSectionEmptyReason
    let onRetry: () -> Void

    var body: some View {
        switch reason {
        case .noMatches(let query):
            ContentUnavailableView {
                Label("No episodes found", systemImage: "magnifyingglass")
            } description: {
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
