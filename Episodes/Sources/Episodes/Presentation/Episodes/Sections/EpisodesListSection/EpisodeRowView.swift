//
//  EpisodeRowView.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import DesignSystem
import Foundation
import SwiftUI

/// One episode: its name, its code and air date, and the characters in it.
struct EpisodeRowView: View {

    /// The avatar's rendered edge, in points.
    private static let avatarSize: CGFloat = 32

    let episode: EpisodeModel

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

            characterStrip
        }
        .padding(.vertical, 4)
        // One element for the whole row: three separate labels and a horizontal
        // scroll view would be dozens of swipes to get past a single episode.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episode.name), \(episode.code), \(episode.airDate)")
        // The strip itself is hidden below, so the count is the only thing that
        // carries it: "12 characters" is the useful summary, and a dozen
        // unlabelled images are not.
        .accessibilityValue(characterCountDescription)
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
            }
        ))

        EpisodeRowView(episode: EpisodeModel(
            id: "2",
            name: "Lawnmower Dog",
            airDate: "December 9, 2013",
            code: "S01E02",
            season: 1,
            number: 2,
            created: nil,
            characters: []
        ))
    }
}
