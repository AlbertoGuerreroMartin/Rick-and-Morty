//
//  CharacterDetailEpisodeRowView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import SwiftUI

/// One episode's name, code, air date, and — when there is one — a button that opens it on HBO Max.
struct CharacterDetailEpisodeRowView: View {
    let episode: CharacterDetailEpisodeModel

    /// `play.hbomax.com` is a universal link, so this opens the HBO Max app when installed.
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            details
            Spacer(minLength: 0)
            watchOnHBOMaxButton
        }
        .padding(.vertical, 10)
    }

    /// Combined on this stack, not the whole row: combining the button too would make it
    /// unreachable to VoiceOver.
    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(episode.name)
                .font(.headline)
                .multilineTextAlignment(.leading)

            Text("\(episode.code) · \(episode.airDate)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episode.name), \(episode.code), \(episode.airDate)")
    }

    /// Shown only when there is somewhere to go.
    @ViewBuilder
    private var watchOnHBOMaxButton: some View {
        if let url = episode.hboMaxURL {
            Button {
                openURL(url)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            // `.automatic` would let an enclosing tappable row swallow the tap.
            .buttonStyle(.borderless)
            .accessibilityLabel("Watch on HBO Max")
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        CharacterDetailEpisodeRowView(episode: CharacterDetailEpisodeModel(
            id: "1",
            name: "Pilot",
            airDate: "December 2, 2013",
            code: "S01E01",
            season: 1,
            number: 1,
            hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/ef7d1c40-2ecc-471a-81a5-7fe06400240a")
        ))

        Divider()

        // No link: draws without a button.
        CharacterDetailEpisodeRowView(episode: CharacterDetailEpisodeModel(
            id: "2",
            name: "Lawnmower Dog",
            airDate: "December 9, 2013",
            code: "S01E02",
            season: 1,
            number: 2,
            hboMaxURL: nil
        ))
    }
    .padding(.horizontal, 16)
}
