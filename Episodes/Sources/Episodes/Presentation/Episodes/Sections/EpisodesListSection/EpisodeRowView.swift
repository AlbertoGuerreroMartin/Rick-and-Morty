//
//  EpisodeRowView.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import DesignSystem
import Foundation
import SwiftUI

/// One episode row: name, code, air date, characters, and an HBO Max button when there is one.
struct EpisodeRowView: View {

    private static let avatarSize: CGFloat = 32

    let episode: EpisodeModel

    /// `play.hbomax.com` is a universal link: opens the app when installed, Safari otherwise.
    @Environment(\.openURL) private var openURL

    /// Not `UITraitCollection.current`: it can default to scale 0 inside a SwiftUI body.
    @Environment(\.displayScale) private var displayScale

    private var avatarPixelSize: CGFloat {
        Self.avatarSize * displayScale
    }

    var body: some View {
        // Sibling of details, not a child, since `details` combines its subtree into one element.
        VStack(alignment: .leading, spacing: 6) {
            details
            characterStrip
        }
        .padding(.vertical, 4)
    }

    private var details: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(episode.name)
                    .font(.headline)

                Text("\(episode.code) · \(episode.airDate)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            watchOnHBOMaxButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episode.name), \(episode.code), \(episode.airDate)")
        .accessibilityValue(characterCountDescription)
    }

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
            // `.borderless`: any style drawing a background lets the `List` row swallow the tap.
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Watch on HBO Max", bundle: .module))
        }
    }

    @ViewBuilder
    private var characterStrip: some View {
        if !episode.characters.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 6) {
                    ForEach(episode.characters) { character in
                        NavigationLink(value: EpisodesRoute.character(id: character.id)) {
                            CachedAsyncImage(url: character.image, maxPixelSize: avatarPixelSize) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(.quaternary)
                            }
                            .frame(width: Self.avatarSize, height: Self.avatarSize)
                            .clipShape(Circle())
                        }
                        // `.plain`: default style tints the photograph with the accent color.
                        .buttonStyle(.plain)
                        .accessibilityLabel(character.name.map { Text($0) }
                            ?? Text("Character \(character.id)", bundle: .module))
                    }
                }
            }
        }
    }

    private var characterCountDescription: String {
        String(localized: "\(episode.characters.count) characters", bundle: .module)
    }
}

#Preview {
    NavigationStack {
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
                        name: "Character \(index)",
                        image: URL(string: "https://rickandmortyapi.com/api/character/avatar/\(index).jpeg")!
                    )
                },
                hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/ef7d1c40-2ecc-471a-81a5-7fe06400240a")
            ))

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
}
