//
//  CharactersFilterBarSectionMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

import Combine
import Core
import Foundation

/// One removable constraint, ready to draw. `field` travels with the title so the ×
/// can tell the view model which constraint to drop without matching on display text.
struct CharactersFilterChip: Identifiable, Equatable, Sendable {
    let field: CharactersFilter.Field
    let title: String

    var id: CharactersFilter.Field { field }
}

struct CharactersFilterBarRenderModel: Equatable, Sendable {
    /// Carried through so the bar can seed the draft the filter sheet edits.
    let filter: CharactersFilter
    let activeCount: Int
    let chips: [CharactersFilterChip]

    static let empty = CharactersFilterBarRenderModel(filter: .empty, activeCount: 0, chips: [])
}

/// What screens and tests resolve; `DataModel` is left to the mapper.
@MainActor
protocol CharactersFilterBarSectionMapperContract: SectionMapperContract
    where ViewModel == any CharactersFilterBarSectionViewModelContract,
          RenderModel == CharactersFilterBarRenderModel {}

@MainActor
final class CharactersFilterBarSectionMapper: CharactersFilterBarSectionMapperContract {
    typealias ViewModel = CharactersFilterBarSectionViewModelContract
    typealias DataModel = CharactersFilter
    typealias RenderModel = CharactersFilterBarRenderModel

    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    func dataPublisher(_ viewModel: ViewModel) -> AnyPublisher<CharactersFilter, Never> {
        viewModel.filterPublisher
    }

    func mapToRenderModel(_ data: CharactersFilter) -> CharactersFilterBarRenderModel {
        let chips = CharactersFilter.Field.allCases.compactMap { field in
            data[field: field].map { CharactersFilterChip(field: field, title: title(for: field, value: $0)) }
        }
        return CharactersFilterBarRenderModel(filter: data,
                                              activeCount: chips.count,
                                              chips: chips)
    }

    /// `type` carries its label; it's free text ("Parasite") indistinguishable from a species.
    private func title(for field: CharactersFilter.Field, value: String) -> String {
        switch field {
        case .type: String(localized: "Type: \(value)", bundle: .module)
        case .status: CharacterStatus(rawValue: value)?.displayName ?? value.capitalized
        case .gender: CharacterGender(rawValue: value)?.displayName ?? value.capitalized
        case .species: value.capitalized
        }
    }
}
