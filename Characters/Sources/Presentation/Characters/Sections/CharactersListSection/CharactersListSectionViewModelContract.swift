//
//  CharactersListSectionViewModelContract.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine

// Main-actor isolated: the conforming view models, the mapper and the section
// views all live on the main actor, and `@Published` projected values can only
// be read from the view model's own isolation domain.
@MainActor
protocol CharactersListSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }
    var charactersPublisher: AnyPublisher<[CharacterModel]?, Never> { get }
    var paginationPublisher: AnyPublisher<CharactersPaginationState, Never> { get }

    /// The filter the rows on screen are the result of. The list needs it for
    /// two things only: highlighting the matched substring, and telling the user
    /// *what* found nothing when the list comes back empty.
    var filterPublisher: AnyPublisher<CharactersFilter, Never> { get }

    /// Whether the last (re)load of page 1 failed. Distinguishes "the query
    /// matched nothing" from "we could not ask", which need different copy and
    /// different buttons.
    var loadFailedPublisher: AnyPublisher<Bool, Never> { get }

    /// Asks for the next page. Idempotent while a page is in flight, and a no-op
    /// at the end of the list, so the section view can call it from a footer
    /// `.task` without guarding anything itself.
    func loadNextPage() async

    /// Re-asks for page 1 with the filter already applied. Drives the Retry
    /// button of the failed empty state.
    func retryLoad()

    /// Drops the four filter fields, keeping the search text. Declared here as
    /// well as on the filter bar's contract because the "no characters found"
    /// state offers the same escape hatch the chip bar does, and the list must
    /// not have to know about the bar to offer it.
    func clearAllFilters()
}
