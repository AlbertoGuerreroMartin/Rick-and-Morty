//
//  CharactersFilterBarSectionViewModelContract.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

import Combine

/// What the chip bar needs from a view model: the applied filter to draw, and
/// three ways to change it.
///
/// It is a separate protocol from the list's rather than one big view model
/// interface because the two sections genuinely need different things — the bar
/// never learns about pagination, the list never learns how to apply a filter —
/// and a section that can only see what it needs is a section that cannot
/// accidentally start depending on the rest.
///
@MainActor
protocol CharactersFilterBarSectionViewModelContract {
    var filterPublisher: AnyPublisher<CharactersFilter, Never> { get }

    /// Applies a whole filter at once — what the sheet's Done button does. The
    /// search text riding inside it is applied unchanged, so opening the sheet
    /// can never drop what the user typed in the search bar.
    func apply(_ filter: CharactersFilter)

    /// Drops one constraint, from a chip's ×.
    func clear(_ field: CharactersFilter.Field)

    /// Drops all four constraints and keeps the search text.
    func clearAllFilters()
}
