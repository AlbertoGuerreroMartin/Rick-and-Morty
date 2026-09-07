//
//  CharactersGridSectionViewModelContract.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine

/// What the grid needs from the view model.
///
/// Deliberately its own protocol rather than a typealias of the list's, even
/// though today the requirements coincide: each section declares what *it*
/// depends on, so the grid can grow (a hero image, a detail push) or the list
/// can shrink without either dragging the other along.
///
/// Main-actor isolated: the conforming view models, the mapper and the section
/// views all live on the main actor, and `@Published` projected values can only
/// be read from the view model's own isolation domain.
@MainActor
protocol CharactersGridSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }
    var charactersPublisher: AnyPublisher<[CharacterModel]?, Never> { get }
    var paginationPublisher: AnyPublisher<CharactersPaginationState, Never> { get }

    /// The filter the cells on screen are the result of, for highlighting the
    /// matched substring and naming *what* found nothing.
    var filterPublisher: AnyPublisher<CharactersFilter, Never> { get }

    /// Whether the last (re)load of page 1 failed.
    var loadFailedPublisher: AnyPublisher<Bool, Never> { get }

    /// Asks for the next page. Idempotent while a page is in flight, and a no-op
    /// at the end, so the footer's `.task` can call it without guarding.
    func loadNextPage() async

    /// Re-asks for page 1 with the filter already applied.
    func retryLoad()

    /// Drops the four filter fields, keeping the search text.
    func clearAllFilters()
}
