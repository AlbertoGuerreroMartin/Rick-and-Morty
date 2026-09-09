//
//  CharacterDetailInfoSectionMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Core
import Foundation

/// One label/value line of the card. Value is baked here, not built in the view, so it can be
/// asserted directly. Label doubles as the id: no two rows share one.
struct CharacterDetailInfoRow: Equatable, Identifiable {
    var id: String { label }
    let label: String
    let value: String
}

enum CharacterDetailInfoRenderModel: Equatable {
    /// The card is absent, not an empty skeleton, while loading.
    case hidden
    case visible(rows: [CharacterDetailInfoRow])
}

/// What screens and tests resolve; `DataModel` is left to the mapper.
@MainActor
protocol CharacterDetailInfoSectionMapperContract: SectionMapperContract
    where ViewModel == any CharacterDetailInfoSectionViewModelContract,
          RenderModel == CharacterDetailInfoRenderModel {}

/// Turns a character into the rows of the card that sits over the picture.
///
/// A row the API has nothing for is dropped rather than shown empty. A place's fields join into
/// one line in API order, skipping gaps. No failure state of its own: the header owns that.
@MainActor
final class CharacterDetailInfoSectionMapper: CharacterDetailInfoSectionMapperContract {
    typealias ViewModel = CharacterDetailInfoSectionViewModelContract
    typealias RenderModel = CharacterDetailInfoRenderModel

    struct DataModel {
        let isLoading: Bool
        let detail: CharacterDetailModel?
    }

    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    func dataPublisher(_ viewModel: ViewModel) -> AnyPublisher<DataModel, Never> {
        viewModel.loadingPublisher
            .combineLatest(viewModel.detailPublisher)
            .map { DataModel(isLoading: $0, detail: $1) }
            .eraseToAnyPublisher()
    }

    func mapToRenderModel(_ data: DataModel) -> CharacterDetailInfoRenderModel {
        guard !data.isLoading, let detail = data.detail else {
            return .hidden
        }

        return .visible(rows: rows(for: detail))
    }

    private func rows(for detail: CharacterDetailModel) -> [CharacterDetailInfoRow] {
        [
            CharacterDetailInfoRow(label: String(localized: "Status", bundle: .module),
                                   value: detail.status.displayName),
            CharacterDetailInfoRow(label: String(localized: "Species", bundle: .module),
                                   value: detail.species),
            detail.type.map { CharacterDetailInfoRow(label: String(localized: "Type", bundle: .module), value: $0) },
            CharacterDetailInfoRow(label: String(localized: "Gender", bundle: .module),
                                   value: detail.gender.displayName),
            place(detail.origin, label: String(localized: "Origin", bundle: .module)),
            place(detail.location, label: String(localized: "Location", bundle: .module))
        ].compactMap { $0 }
    }

    /// Never empty: the entity mapper drops places with no name before this is reached.
    private func place(_ place: CharacterDetailPlaceModel?, label: String) -> CharacterDetailInfoRow? {
        guard let place else { return nil }
        let value = [place.name, place.type, place.dimension]
            .compactMap { $0 }
            .joined(separator: " · ")
        return CharacterDetailInfoRow(label: label, value: value)
    }
}
