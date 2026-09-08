//
//  LocationDetailSectionMapper.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine
import Core
import Foundation

/// One line of the card. Label doubles as `Identifiable` id: the card never repeats a label.
struct LocationDetailInfoRow: Equatable, Identifiable {
    var id: String { label }
    let label: String
    let value: String
}

/// Everything the card draws for one location.
struct LocationDetailContent: Equatable {
    let name: String
    let rows: [LocationDetailInfoRow]
    let residents: [LocationResidentModel]
    let residentsDescription: String
}

enum LocationDetailRenderModel: Equatable {
    /// Absent, not empty: avoids a second loading indicator under the carousel's own spinner.
    case hidden
    case visible(LocationDetailContent)
}

protocol LocationDetailSectionMapperContract: SectionMapperContract {}

/// Resolves the selected id against the loaded locations and turns the answer into the card.
/// Resolved here, not stored as a `LocationModel`, so a reload can't leave the card describing
/// a location the carousel no longer has. A row with no value is omitted; the API's own literal
/// `"unknown"` is kept as a real value, distinct from no record at all.
@MainActor
final class LocationDetailSectionMapper: LocationDetailSectionMapperContract {
    typealias ViewModel = LocationDetailSectionViewModelContract
    typealias RenderModel = LocationDetailRenderModel

    struct DataModel {
        let locations: [LocationModel]?
        let selectedId: String?
    }

    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    func dataPublisher(_ viewModel: ViewModel) -> AnyPublisher<DataModel, Never> {
        viewModel.locationsPublisher
            .combineLatest(viewModel.selectedLocationIdPublisher)
            .map { DataModel(locations: $0, selectedId: $1) }
            .eraseToAnyPublisher()
    }

    func mapToRenderModel(_ data: DataModel) -> LocationDetailRenderModel {
        guard let locations = data.locations,
              let selectedId = data.selectedId,
              let location = locations.first(where: { $0.id == selectedId }) else {
            return .hidden
        }

        return .visible(content(for: location))
    }

    private func content(for location: LocationModel) -> LocationDetailContent {
        LocationDetailContent(name: location.name,
                              rows: rows(for: location),
                              residents: location.residents,
                              residentsDescription: Self.residentsDescription(location.residents.count))
    }

    private func rows(for location: LocationModel) -> [LocationDetailInfoRow] {
        [
            location.type.map { LocationDetailInfoRow(label: "Type", value: $0) },
            location.dimension.map { LocationDetailInfoRow(label: "Dimension", value: $0) }
        ].compactMap { $0 }
    }

    private static func residentsDescription(_ count: Int) -> String {
        switch count {
        case 0: "No residents"
        case 1: "1 resident"
        default: "\(count) residents"
        }
    }
}
