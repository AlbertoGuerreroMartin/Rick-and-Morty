//
//  StubCharactersFilterBarViewModel.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Combine
import Foundation
@testable import Characters

@MainActor
final class StubCharactersFilterBarViewModel: CharactersFilterBarSectionViewModelContract {
    @Published var filter: CharactersFilter = .empty

    private(set) var appliedFilters: [CharactersFilter] = []
    private(set) var clearedFields: [CharactersFilter.Field] = []
    private(set) var clearAllCallCount = 0

    var filterPublisher: AnyPublisher<CharactersFilter, Never> { $filter.eraseToAnyPublisher() }

    func apply(_ filter: CharactersFilter) {
        appliedFilters.append(filter)
    }

    func clear(_ field: CharactersFilter.Field) {
        clearedFields.append(field)
    }

    func clearAllFilters() {
        clearAllCallCount += 1
    }
}
