//
//  CharacterDetailInfoSectionView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Core
import SwiftUI

/// The character's facts, as a card that sits *over* the bottom of the picture.
struct CharacterDetailInfoSectionView: SectionViewContract {
    private static let overlap: CGFloat = 24
    private static let horizontalPadding: CGFloat = 16
    private static let cornerRadius: CGFloat = 20

    /// Held to satisfy `SectionViewContract`; this section draws only what the mapper produces.
    let viewModel: any CharacterDetailInfoSectionViewModelContract

    let renderModelPublisher: AnyPublisher<CharacterDetailInfoRenderModel, Never>

    @State var renderModel: CharacterDetailInfoRenderModel = .hidden

    init(viewModel: any CharacterDetailInfoSectionViewModelContract,
         renderModelPublisher: AnyPublisher<CharacterDetailInfoRenderModel, Never>) {
        self.viewModel = viewModel
        self.renderModelPublisher = renderModelPublisher
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.label)
        .accessibilityValue(row.value)
    }
}
