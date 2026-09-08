//
//  LocationDetailSectionMapper.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine
import Core
import Foundation

/// One line of the card: a label and the value beside it.
///
/// Both are *display strings*, baked here rather than in the view. That is the
/// point of the whole render model: copy that lives in a `Text` interpolation
/// can only be checked by looking at a screenshot, while baked into a value
/// every rule below is one assertion in `LocationDetailSectionMapperTests`.
///
/// The label doubles as the identity: the card never shows two rows with the
/// same label, and giving `ForEach` a stable key that is also the thing the user
/// reads means there is no separate id to keep in step.
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
    /// "12 residents". Baked here because it is the accessibility *value* of the
    /// strip, and a count that is pluralized in a view body is a rule nothing
    /// asserts.
    let residentsDescription: String
}

enum LocationDetailRenderModel: Equatable {
    /// Nothing to describe. The card is absent rather than empty — a skeleton
    /// under a carousel that is already showing a spinner would be two loading
    /// indicators for one request.
    case hidden
    case visible(LocationDetailContent)
}

protocol LocationDetailSectionMapperContract: SectionMapperContract {}

/// Resolves the selected id against the loaded locations and turns the answer
/// into the card.
///
/// **The id is resolved here, every time.** The alternative — the view model
/// publishing the selected `LocationModel` — would hold a second copy of a
/// location that is already in the list, and a reload replacing the list would
/// leave the card describing a place the carousel no longer has. Looking it up
/// means the card is, by construction, describing something on screen.
///
/// Two rules run through the rows, and they are the character detail's rules
/// because they are right for the same reason. **A row the API has nothing for
/// is not drawn** — no "Type: —", no invented "unknown" — because a labelled row
/// with nothing after it is worse than one line less. And **the API's own
/// literal `"unknown"` is kept verbatim**: it is a name, the one the show gives
/// to an uncharted dimension, and rewriting it would throw away the difference
/// between "the API says unknown" and "there is no record", only the first of
/// which is worth showing.
///
/// The `id` is never a row. It is what the selection is published as and what
/// `ForEach` keys on, and the user has no use for it: unlike a character, whose
/// id is how every other tool that talks about this API names it, a location is
/// identified everywhere by its name.
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
        // Three ways to have nothing to describe, and they collapse into one
        // state on purpose: nothing loaded, nothing selected, and an id that is
        // not in the list all mean the same thing to the user — there is no card
        // — and the carousel above is where the reason for it is shown.
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

    /// Type first, then dimension: what the place *is* before where it is, the
    /// same order the API lists them in and the same order the character card
    /// reads a place out in.
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
