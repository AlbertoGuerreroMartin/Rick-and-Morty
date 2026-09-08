//
//  CharactersGridSectionViewModelContract.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine

/// What the grid needs from the view model. Its own protocol rather than a typealias of the
/// list's, so the grid and list can grow or shrink independently.
@MainActor
protocol CharactersGridSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }
    var charactersPublisher: AnyPublisher<[CharacterModel]?, Never> { get }
    var paginationPublisher: AnyPublisher<CharactersPaginationState, Never> { get }

    /// For highlighting the matched substring and naming what found nothing.
    var filterPublisher: AnyPublisher<CharactersFilter, Never> { get }

    /// Whether the last (re)load of page 1 failed.
    var loadFailedPublisher: AnyPublisher<Bool, Never> { get }

    /// Idempotent while a page is in flight, and a no-op at the end.
    func loadNextPage() async

    /// Re-asks for page 1 with the filter already applied.
    func retryLoad()

    /// Drops the four filter fields, keeping the search text.
    func clearAllFilters()
}
