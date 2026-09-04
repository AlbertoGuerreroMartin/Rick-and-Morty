//
//  CharactersListSectionView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine
import DesignSystem
import SwiftUI

struct CharactersListSectionView: View {
    /// The avatar's rendered edge, in points.
    private static let avatarSize: CGFloat = 56

    /// The screen's pixels per point. Read from the SwiftUI environment rather
    /// than `UITraitCollection.current`: UIKit only populates the latter while
    /// it is calling into UIKit code (layout, drawing), so inside a SwiftUI body
    /// it can be the default trait collection whose scale is 0 — and a 0px
    /// decode target would turn every avatar into a 1px smear.
    @Environment(\.displayScale) private var displayScale

    /// The avatar edge in *pixels*, which is what the downsampler decodes to.
    /// Decoding at point size would be soft on every device shipped this decade;
    /// decoding at the source's own size would hold a full-resolution bitmap per
    /// row.
    private var avatarPixelSize: CGFloat {
        Self.avatarSize * displayScale
    }

    private let renderModelPublisher: AnyPublisher<CharactersListRenderModel, Never>
    
    @State var renderModel: CharactersListRenderModel = .hidden
    
    init(mapper: CharactersListSectionMapper) {
        self.renderModelPublisher = mapper.renderModelPublisher()
    }
    
    var body: some View {
        content
            .onReceive(renderModelPublisher) {
                renderModel = $0
            }
    }
    
    @ViewBuilder
    var content: some View {
        switch renderModel {
        case .visible(let characters):
            charactersList(characters: characters)
        case .hidden:
            ProgressView()
        }
    }
    
    @ViewBuilder
    func charactersList(characters: [CharacterModel]) -> some View {
        List(characters, id: \.id) { character in
            characterRow(character: character)
        }
    }
    
    @ViewBuilder
    func characterRow(character: CharacterModel) -> some View {
        HStack(spacing: 12) {
            // `CachedAsyncImage` rather than `AsyncImage`: it keeps the decoded
            // bitmap and the downloaded bytes, so a row scrolling back into view
            // draws immediately instead of flashing a placeholder and
            // re-decoding — and a relaunch costs no requests at all.
            CachedAsyncImage(url: character.image, maxPixelSize: avatarPixelSize) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .frame(width: Self.avatarSize, height: Self.avatarSize)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(character.name)
                    .font(.headline)
                HStack(spacing: 5) {
                    Circle()
                        .fill(character.status.color)
                        .frame(width: 7, height: 7)
                    Text("\(character.status.rawValue.capitalized) · \(character.species)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                let dimension = character.location.dimension.flatMap { "(\($0))" } ?? ""
                Text("\(character.location.name) \(dimension)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)

    }
}
