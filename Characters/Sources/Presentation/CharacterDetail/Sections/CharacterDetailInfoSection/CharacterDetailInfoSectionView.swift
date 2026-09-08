//
//  CharacterDetailInfoSectionView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import SwiftUI

/// The character's facts, as a card that sits *over* the bottom of the picture.
///
/// The overlap is the whole visual idea of the screen. A negative top padding
/// pulls the card up across the header's edge and the shadow lifts it off the
/// image, so the picture reads as something the card is resting on rather than
/// as a banner the content starts underneath. It costs one modifier and gives
/// the screen a shape a stack of full-width rows does not have.
struct CharacterDetailInfoSectionView: View {
    /// How far the card rides up over the picture. The header reserves matching
    /// room under its title text, so the two numbers are a pair: raise this and
    /// the name goes under the card.
    private static let overlap: CGFloat = 24
    private static let horizontalPadding: CGFloat = 16
    private static let cornerRadius: CGFloat = 20

    private let renderModelPublisher: AnyPublisher<CharacterDetailInfoRenderModel, Never>

    @State var renderModel: CharacterDetailInfoRenderModel = .hidden

    /// No view model. This section has nothing to call: the header owns the
    /// Retry, and a card with no character simply is not there.
    init(mapper: CharacterDetailInfoSectionMapper) {
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
        case .visible(let rows):
            card(rows: rows)
        case .hidden:
            EmptyView()
        }
    }

    @ViewBuilder
    func card(rows: [CharacterDetailInfoRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider()
                }
                infoRow(row)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        // `.background` rather than a fixed colour: the card is the one surface
        // on this screen that is *not* the picture, so it follows light and dark
        // mode while the header deliberately does not.
        .background(.background, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.top, -Self.overlap)
    }

    @ViewBuilder
    func infoRow(_ row: CharacterDetailInfoRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(row.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(row.value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
        // One element per row: "Origin, Earth · Planet" is the fact, and hearing
        // the label and the value as two stops would double the swipes for
        // nothing.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.label)
        .accessibilityValue(row.value)
    }
}
