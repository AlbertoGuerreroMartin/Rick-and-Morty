//
//  LocationDetailSectionView.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine
import SwiftUI

/// Everything under the carousel: what the circle at the focus actually is.
///
/// It has no view model. There is nothing for this section to call — the
/// carousel above owns the Retry and the pagination, and a card with no location
/// simply is not there — so it takes a mapper and draws what comes out of it.
struct LocationDetailSectionView: View {

    private let renderModelPublisher: AnyPublisher<LocationDetailRenderModel, Never>

    @State var renderModel: LocationDetailRenderModel = .hidden

    init(mapper: LocationDetailSectionMapper) {
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
        case .visible(let content):
            card(content)
        case .hidden:
            // A `Color.clear` and not an `EmptyView`: this section is the rest
            // of a `VStack` whose top is a carousel taking its natural height,
            // and a zero-height sibling would let that carousel drift down to
            // the middle of the screen and jump back up when the card arrived.
            // Holding the space is what keeps the layout still.
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    func card(_ content: LocationDetailContent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(content.name)
                .font(.title3.weight(.semibold))
                .lineLimit(2)

            if !content.rows.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(content.rows) { row in
                        infoRow(row)
                    }
                }
                .padding(.top, 10)
            }

            LocationResidentsListView(residents: content.residents)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    func infoRow(_ row: LocationDetailInfoRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(row.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(row.value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
        // One element per row: "Dimension, C-137" is the fact, and hearing the
        // label and the value as two stops would double the swipes for nothing.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.label)
        .accessibilityValue(row.value)
    }
}

#Preview("A location with everything") {
    LocationDetailSectionView.PreviewCard(content: LocationDetailContent(
        name: "Earth (C-137)",
        rows: [LocationDetailInfoRow(label: "Type", value: "Planet"),
               LocationDetailInfoRow(label: "Dimension", value: "Dimension C-137")],
        residents: (1...8).map { index in
            LocationResidentModel(id: "\(index)",
                                  name: "\(index)",
                                  image: URL(string: "https://rickandmortyapi.com/api/character/avatar/\(index).jpeg")!)
        },
        residentsDescription: "8 residents"
    ))
}

#Preview("A location with nothing") {
    LocationDetailSectionView.PreviewCard(content: LocationDetailContent(
        name: "Worldender's lair",
        rows: [],
        residents: [],
        residentsDescription: "No residents"
    ))
}

extension LocationDetailSectionView {
    /// The card on its own, with no publisher behind it.
    ///
    /// The section needs a mapper to exist, and a mapper needs a view model —
    /// which is three objects to stand up for a canvas that only wants to look
    /// at a layout. This draws the same `card(_:)` the section does, so the
    /// preview cannot drift from what ships.
    struct PreviewCard: View {
        let content: LocationDetailContent

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(content.name)
                    .font(.title3.weight(.semibold))
                ForEach(content.rows) { row in
                    HStack {
                        Text(row.label).foregroundStyle(.secondary)
                        Spacer()
                        Text(row.value)
                    }
                    .font(.subheadline)
                }
                LocationResidentsListView(residents: content.residents)
            }
            .padding()
        }
    }
}
