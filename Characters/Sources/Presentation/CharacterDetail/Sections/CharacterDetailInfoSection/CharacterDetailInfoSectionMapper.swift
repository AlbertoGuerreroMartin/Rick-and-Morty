//
//  CharacterDetailInfoSectionMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Core
import Foundation

/// One line of the card: a label and the value beside it.
///
/// Both are *display strings*, baked here rather than in the view. That is the
/// point of the whole render model: "Origin" reading `Earth (C-137) · Planet ·
/// Dimension C-137` is copy, and copy that lives in a `Text` interpolation can
/// only be checked by looking at a screenshot. Baked into a value, every rule
/// below is one assertion in `CharacterDetailInfoSectionMapperTests`.
///
/// The label doubles as the identity: the card never shows two rows with the
/// same label, and giving `ForEach` a stable key that is also the thing the user
/// reads means there is no separate id to keep in step.
struct CharacterDetailInfoRow: Equatable, Identifiable {
    var id: String { label }
    let label: String
    let value: String
}

enum CharacterDetailInfoRenderModel: Equatable {
    /// Nothing to describe yet. The card is absent rather than empty — a
    /// skeleton card under a spinner would be two loading indicators for one
    /// request.
    case hidden
    case visible(rows: [CharacterDetailInfoRow])
}

protocol CharacterDetailInfoSectionMapperContract: SectionMapperContract {}

/// Turns a character into the rows of the card that sits over the picture.
///
/// Two rules run through all of it. **A row the API has nothing for is not
/// drawn** — no "Type: —", no "Origin: unknown" invented by this app — because a
/// labelled row with nothing after it is worse than one line less. And **a
/// place's three fields are joined into one line**, in the order the API gives
/// them, skipping whatever is missing: `Earth (C-137) · Planet · Dimension
/// C-137` when all three are there, just the name when only it is.
///
/// The card deliberately has no failure state of its own: the header owns the
/// spinner and the Retry, so this section only ever describes a character it
/// actually has.
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

    /// The order is the one the screen reads in: what the character *is* first,
    /// then where it is from and where it is now, then the bookkeeping.
    private func rows(for detail: CharacterDetailModel) -> [CharacterDetailInfoRow] {
        [
            CharacterDetailInfoRow(label: "Status", value: detail.status.rawValue.capitalized),
            CharacterDetailInfoRow(label: "Species", value: detail.species),
            detail.type.map { CharacterDetailInfoRow(label: "Type", value: $0) },
            CharacterDetailInfoRow(label: "Gender", value: detail.gender.rawValue.capitalized),
            place(detail.origin, label: "Origin"),
            place(detail.location, label: "Location"),
        ].compactMap { $0 }
    }

    /// `name · type · dimension`, minus whatever is absent. A place with no name
    /// never reaches here — the entity mapper drops it — so the joined string is
    /// never empty.
    private func place(_ place: CharacterDetailPlaceModel?, label: String) -> CharacterDetailInfoRow? {
        guard let place else { return nil }
        let value = [place.name, place.type, place.dimension]
            .compactMap { $0 }
            .joined(separator: " · ")
        return CharacterDetailInfoRow(label: label, value: value)
    }
}
