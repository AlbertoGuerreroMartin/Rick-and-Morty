//
//  LocationDetailSectionView.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine
import SwiftUI

/// Everything under the carousel: what the circle at the focus actually is. No view model —
/// the carousel owns retry and pagination — so this just draws what the mapper produces.
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
            // `Color.clear`, not `EmptyView`: holds the space so the carousel above doesn't drift.
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
                .padding(.horizontal, 20)

            if !content.rows.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(content.rows) { row in
                        infoRow(row)
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
            }

            LocationResidentsListView(residents: content.residents)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                                  status: .alive,
                                  species: "Human",
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
    /// The card with no publisher behind it, for previews that don't want to stand up a view model.
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
