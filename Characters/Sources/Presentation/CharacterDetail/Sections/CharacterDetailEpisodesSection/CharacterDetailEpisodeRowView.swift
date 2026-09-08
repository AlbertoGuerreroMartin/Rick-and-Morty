//
//  CharacterDetailEpisodeRowView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import SwiftUI

/// One episode: its name, its code and air date, and — when there is one — a
/// button that opens it on HBO Max.
///
/// Deliberately three lines and a button, with no character strip: this row is
/// already inside a character's page, so a row of avatars would be showing the
/// user the character they are looking at, once per episode.
struct CharacterDetailEpisodeRowView: View {
    let episode: CharacterDetailEpisodeModel

    /// Opens the HBO Max link through the environment rather than
    /// `UIApplication.shared.open`. `play.hbomax.com` registers a universal link
    /// for the HBO Max app, so the system opens the app when it is installed and
    /// Safari when it is not — and reaching for `UIApplication` from a SwiftUI
    /// body would drag UIKit into a view that otherwise has no need of it.
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            details
            Spacer(minLength: 0)
            watchOnHBOMaxButton
        }
        .padding(.vertical, 10)
    }

    /// Everything the row *says*, as one accessibility element.
    ///
    /// The combining is on this stack and not on the whole row, which is the
    /// difference between the button being reachable and not: `children:
    /// .combine` flattens its subtree into a single element, so a button inside
    /// it would stop being something VoiceOver can move to and activate. Split
    /// this way the row is two elements — the episode, then its button — which
    /// is also the right number to swipe through.
    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(episode.name)
                .font(.headline)
                .multilineTextAlignment(.leading)

            // The code verbatim, as the API spells it: it is what appears on
            // every episode guide the user has ever seen, so reformatting it
            // into "Season 1, Episode 5" would be this app inventing its own
            // dialect for something already standard.
            Text("\(episode.code) · \(episode.airDate)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episode.name), \(episode.code), \(episode.airDate)")
    }

    /// Shown only when there is somewhere to go.
    ///
    /// An always-present button that sometimes did nothing — or opened a search
    /// — would promise something the app cannot deliver for an episode HBO Max
    /// does not carry. The absence is the honest state, and it costs the row
    /// nothing: the details take the full width either way.
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
            // Not decoration: any button style that draws a background —
            // `.automatic` included — lets an enclosing tappable row swallow the
            // tap. `.borderless` is what keeps the two apart, and this row will
            // become tappable the day an episode gets a screen of its own.
            .buttonStyle(.borderless)
            // The image is a play triangle and says nothing about where it goes,
            // so the label has to carry the whole meaning of the control.
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

        // No link: an episode HBO Max does not carry, or a JustWatch lookup that
        // did not answer. The row draws without a button.
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
