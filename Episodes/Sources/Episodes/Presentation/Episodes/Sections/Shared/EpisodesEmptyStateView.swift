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
                Label {
                    Text("No episodes found", bundle: .module)
                } icon: {
                    Image(systemName: "magnifyingglass")
                }
            } description: {
                if let query {
                    Text("No results for \u{201C}\(query)\u{201D}.", bundle: .module)
                } else {
                    Text("There are no episodes to show.", bundle: .module)
                }
            }
        case .failed:
            ContentUnavailableView {
                Label {
                    Text("Couldn't load episodes", bundle: .module)
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

#Preview("No matches") {
    EpisodesEmptyStateView(reason: .noMatches(query: "squanch"), onRetry: {})
}

#Preview("Failed") {
    EpisodesEmptyStateView(reason: .failed, onRetry: {})
}
