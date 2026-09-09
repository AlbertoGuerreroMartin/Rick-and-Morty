//
//  StubCharactersSectionViewModel.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Combine
import Foundation
@testable import Characters

@MainActor
final class StubCharactersSectionViewModel: CharactersListSectionViewModelContract,
                                            CharactersGridSectionViewModelContract {
    @Published var isLoading = false
    @Published var characters: [CharacterModel]?
    @Published var pagination: CharactersPaginationState = .end
    @Published var filter: CharactersFilter = .empty
    @Published var loadFailed = false

    var loadingPublisher: AnyPublisher<Bool, Never> { $isLoading.eraseToAnyPublisher() }
    var charactersPublisher: AnyPublisher<[CharacterModel]?, Never> { $characters.eraseToAnyPublisher() }
    var paginationPublisher: AnyPublisher<CharactersPaginationState, Never> { $pagination.eraseToAnyPublisher() }
    var filterPublisher: AnyPublisher<CharactersFilter, Never> { $filter.eraseToAnyPublisher() }
    var loadFailedPublisher: AnyPublisher<Bool, Never> { $loadFailed.eraseToAnyPublisher() }

    func loadNextPage() async {}
    func retryLoad() {}
    func clearAllFilters() {}
}
