//
//  EpisodeRowView.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import DesignSystem
import Foundation
import SwiftUI

/// One episode: its name, its code and air date, the characters in it, and — when
/// there is one — a button that opens it on HBO Max.
struct EpisodeRowView: View {

    /// The avatar's rendered edge, in points.
    private static let avatarSize: CGFloat = 32

    let episode: EpisodeModel

    /// Opens the HBO Max link through the environment rather than
    /// `UIApplication.shared.open`. `play.hbomax.com` registers a universal link
    /// for the HBO Max app, so the system opens the app when it is installed and
    /// Safari when it is not — and reaching for `UIApplication` from a SwiftUI
    /// body would drag UIKit into a view that otherwise has no need of it.
    @Environment(\.openURL) private var openURL

    /// The screen's pixels per point. Read from the SwiftUI environment rather
    /// than `UITraitCollection.current`: UIKit only populates the latter while
    /// it is calling into UIKit code (layout, drawing), so inside a SwiftUI body
    /// it can be the default trait collection whose scale is 0 — and a 0px
    /// decode target would turn every avatar into a 1px smear.
    @Environment(\.displayScale) private var displayScale

    /// The avatar edge in *pixels*, which is what the downsampler decodes to.
    /// Decoding at point size would be soft on every device shipped this decade;
    /// decoding at the source's own size would hold a 300x300 bitmap for each of
    /// the dozens of characters in an episode, several episodes at a time.
    private var avatarPixelSize: CGFloat {
        Self.avatarSize * displayScale
    }

    var body: some View {
        // Centred rather than top-aligned: the button is one small control
        // against a block that is two or three lines tall, and pinning it to the
        // top would leave it floating beside the title instead of reading as
        // belonging to the row.
        details
            .padding(.vertical, 4)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(episode.name)
                        .font(.headline)

                    // The code verbatim, as the API spells it: it is what appears on
                    // every episode guide the user has ever seen, so reformatting it
                    // into "Season 1, Episode 5" would be this app inventing its own
                    // dialect for something already standard.
                    Text("\(episode.code) · \(episode.airDate)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                watchOnHBOMaxButton
            }
            characterStrip
        }
        // Takes the width so the button sits at the trailing edge of the row
        // rather than immediately after the longest line of text.
        .frame(maxWidth: .infinity, alignment: .leading)
        // One element for the text: three separate labels and a horizontal
        // scroll view would be dozens of swipes to get past a single episode.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episode.name), \(episode.code), \(episode.airDate)")
        // The strip itself is hidden below, so the count is the only thing that
        // carries it: "12 characters" is the useful summary, and a dozen
        // unlabelled images are not.
        .accessibilityValue(characterCountDescription)
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
            // Not decoration: a `List` row is itself tappable, and any button
            // style that draws a background — `.automatic` included — lets the
            // row swallow the tap so that the whole row activates instead of the
            // button. `.borderless` is what keeps the two apart.
            .buttonStyle(.borderless)
            // The image is a play triangle and says nothing about where it goes,
            // so the label has to carry the whole meaning of the control.
            .accessibilityLabel("Watch on HBO Max")
        }
    }

    /// A horizontal strip rather than a wrapped grid: an episode can have
    /// dozens of characters, and letting them grow downwards would make one row
    /// as tall as the screen.
    ///
    /// `LazyHStack` inside the `ScrollView` so only the avatars actually on
    /// screen are built — the strip is offscreen work by default, since most of
    /// it is scrolled out of view in a row the user never swipes.
    @ViewBuilder
    private var characterStrip: some View {
        if !episode.characters.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 6) {
                    // Keyed on the character's id, not the offset. Nothing taps
                    // through today, but the id being the identity here is what
                    // makes adding that a one-line change rather than a trip
                    // back through the model, the mapper and the query.
                    ForEach(episode.characters) { character in
                        CachedAsyncImage(url: character.image, maxPixelSize: avatarPixelSize) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(.quaternary)
                        }
                        .frame(width: Self.avatarSize, height: Self.avatarSize)
                        .clipShape(Circle())
                    }
                }
            }
            // Decorative, and expensive to hear: VoiceOver reading "image" once
            // per character would bury the episode's name under thirty of them.
            // The count on the row above says everything the strip conveys.
            .accessibilityHidden(true)
        }
    }

    private var characterCountDescription: String {
        switch episode.characters.count {
        case 0: "No characters"
        case 1: "1 character"
        case let count: "\(count) characters"
        }
    }
}

#Preview {
    List {
        EpisodeRowView(episode: EpisodeModel(
            id: "1",
            name: "Pilot",
            airDate: "December 2, 2013",
            code: "S01E01",
            season: 1,
            number: 1,
            created: nil,
            characters: (1...12).map { index in
                EpisodeCharacterModel(
                    id: "\(index)",
                    image: URL(string: "https://rickandmortyapi.com/api/character/avatar/\(index).jpeg")!
                )
            },
            hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/ef7d1c40-2ecc-471a-81a5-7fe06400240a")
        ))

        // Deliberately linked and characterless: the two things a row can be
        // missing are independent, and the button has to sit correctly against a
        // two-line block as well as against a tall one.
        EpisodeRowView(episode: EpisodeModel(
            id: "2",
            name: "Lawnmower Dog",
            airDate: "December 9, 2013",
            code: "S01E02",
            season: 1,
            number: 2,
            created: nil,
            characters: [],
            hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/8a76d2c8-2ba4-4b6a-9c6a-0b2b1c9a2f10")
        ))

        // No link: an episode HBO Max does not carry, or a JustWatch lookup that
        // did not answer. The row draws without a button.
        EpisodeRowView(episode: EpisodeModel(
            id: "3",
            name: "Anatomy Park",
            airDate: "December 16, 2013",
            code: "S01E03",
            season: 1,
            number: 3,
            created: nil,
            characters: [],
            hboMaxURL: nil
        ))
    }
}
