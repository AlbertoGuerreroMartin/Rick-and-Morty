//
//  CharactersFilterBarSectionViewModelContract.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

import Combine

/// What the chip bar needs from a view model: the applied filter, and three ways to change it.
@MainActor
protocol CharactersFilterBarSectionViewModelContract {
    var filterPublisher: AnyPublisher<CharactersFilter, Never> { get }

    /// What the sheet's Done button does; the search text riding along is applied unchanged.
    func apply(_ filter: CharactersFilter)

    /// Drops one constraint, from a chip's ×.
    func clear(_ field: CharactersFilter.Field)

    /// Drops all four constraints and keeps the search text.
    func clearAllFilters()
}
