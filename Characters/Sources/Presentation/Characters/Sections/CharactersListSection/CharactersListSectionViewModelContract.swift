//
//  CharactersListSectionViewModelContract.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine

// `@Published` projected values can only be read from the view model's own isolation domain.
@MainActor
protocol CharactersListSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }
    var charactersPublisher: AnyPublisher<[CharacterModel]?, Never> { get }
    var paginationPublisher: AnyPublisher<CharactersPaginationState, Never> { get }

    /// For highlighting the matched substring and naming what found nothing.
    var filterPublisher: AnyPublisher<CharactersFilter, Never> { get }

    /// Whether the last (re)load of page 1 failed.
    var loadFailedPublisher: AnyPublisher<Bool, Never> { get }

    /// Idempotent while a page is in flight, and a no-op at the end of the list.
    func loadNextPage() async

    /// Re-asks for page 1 with the filter already applied.
    func retryLoad()

    /// Drops the four filter fields, keeping the search text.
    func clearAllFilters()
}
