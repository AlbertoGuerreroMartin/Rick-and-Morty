//
//  CharactersFilterBarSectionMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

import Combine
import Core

/// One removable constraint, ready to draw.
///
/// The `field` travels with the title because the × has to tell the view model
/// *which* constraint to drop, and matching on a display string to work that out
/// would break the first time the copy changed.
struct CharactersFilterChip: Identifiable, Equatable, Sendable {
    let field: CharactersFilter.Field
    let title: String

    /// A field appears at most once, so it is its own identity — no synthetic
    /// UUID that would change on every mapping and re-animate the whole bar.
    var id: CharactersFilter.Field { field }
}

struct CharactersFilterBarRenderModel: Equatable, Sendable {
    /// The applied filter, carried through so the bar can seed the sheet it
    /// presents. The sheet edits a *draft* of it, which is why the bar needs the
    /// value and not just the summary the chips are made of.
    let filter: CharactersFilter
    let activeCount: Int
    let chips: [CharactersFilterChip]

    static let empty = CharactersFilterBarRenderModel(filter: .empty, activeCount: 0, chips: [])
}

protocol CharactersFilterBarSectionMapperContract: SectionMapperContract {}

/// The simplest mapper in the feature: one publisher in, a list of capsules out.
///
/// It exists anyway, rather than the bar reading the filter directly, because
/// the alternative is a view that formats domain values — and "how a status
/// becomes the word Alive" is presentation logic that deserves a test without a
/// view hierarchy.
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

    /// Status, gender and species speak for themselves as chips — "Alive",
    /// "Female", "Human" all read as what they are. `type` does not: the API's
    /// type is a free-text sub-species ("Parasite", "Clone") that is
    /// indistinguishable from a species at a glance, so it is the one field that
    /// carries its label.
    private func title(for field: CharactersFilter.Field, value: String) -> String {
        switch field {
        case .type: "Type: \(value)"
        case .status, .gender, .species: value.capitalized
        }
    }
}
