//
//  CharactersViewModel.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine
import Networking

@MainActor
final class CharactersViewModel: CharactersListSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> {
        $loadingPublished.eraseToAnyPublisher()
    }

    var charactersPublisher: AnyPublisher<[CharacterModel]?, Never> {
        $charactersPublished.eraseToAnyPublisher()
    }

    var paginationPublisher: AnyPublisher<CharactersPaginationState, Never> {
        $paginationPublished.eraseToAnyPublisher()
    }

    let charactersUseCase: CharactersUseCaseContract

    init(charactersUseCase: CharactersUseCaseContract) {
        self.charactersUseCase = charactersUseCase
    }

    /// The *initial* load only. Later pages have their own state below, so that
    /// appending page 5 never blanks the four pages already on screen.
    @Published var loadingPublished = false
    /// Every character loaded so far, across all pages, in arrival order.
    @Published var charactersPublished: [CharacterModel]?
    /// Starts at `.end` — before the first page lands there is provably nothing
    /// *more* to load, and that keeps the footer out of the way until
    /// `loadData()` has seen an `info.next`.
    @Published var paginationPublished: CharactersPaginationState = .end

    private var hasLoaded = false
    private var isFetching = false

    /// The in-flight *next page* request, owned by the view model rather than by
    /// the caller. See `loadNextPage()`.
    private var nextPageTask: Task<Void, Never>?

    func loadData() async {
        // `.task` is bound to the view's appear/disappear lifetime, so it fires
        // again on every return to the tab. Only the first one does any work.
        guard !hasLoaded, !isFetching else { return }

        isFetching = true
        loadingPublished = true
        defer { isFetching = false }

        do {
            let page = try await charactersUseCase.fetchCharacters(page: 1)
            charactersPublished = page.characters
            paginationPublished = CharactersPaginationState(nextPage: page.nextPage)
            hasLoaded = true
            loadingPublished = false
        } catch {
            // A cancelled fetch (leaving the tab mid-load) keeps the loading
            // state untouched so the next appear retries, instead of falling
            // through to an empty list.
            guard !Task.isCancelled else { return }
            charactersPublished = []
            paginationPublished = .end
            loadingPublished = false
        }
    }

    /// Loads the page the pagination state is pointing at, if any.
    ///
    /// The awaited work lives in a `Task` the *view model* owns, and the caller
    /// only awaits its value. That indirection is the point: the trigger is a
    /// `.task` on the list's footer row, and SwiftUI cancels it the moment the
    /// row scrolls out of the `List`'s lazy window. Cancelling a request that
    /// has already left the device buys nothing and costs a lot here —
    /// rickandmortyapi answers **429** to a client that asks too often, so the
    /// abandoned request still counts against the budget while its response is
    /// thrown away. Owning the task means a flick past the footer costs one
    /// request that is actually kept.
    ///
    /// Only one page is ever in flight; a second caller (a re-fired `.task`, the
    /// retry button) joins the existing task instead of starting a new one.
    func loadNextPage() async {
        guard let task = nextPageTask ?? makeNextPageTask() else { return }
        // `task` is unstructured, so cancelling *this* caller does not cancel it.
        await task.value
    }

    /// - Returns: the newly started task, or `nil` when there is nothing to load
    ///   (end of the list, or a request already running).
    private func makeNextPageTask() -> Task<Void, Never>? {
        let page: Int
        switch paginationPublished {
        case .idle(let nextPage), .failed(let nextPage):
            page = nextPage
        case .loading, .end:
            return nil
        }

        paginationPublished = .loading

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.nextPageTask = nil }

            do {
                let result = try await charactersUseCase.fetchCharacters(page: page)
                charactersPublished = (charactersPublished ?? []) + result.characters
                paginationPublished = CharactersPaginationState(nextPage: result.nextPage)
            } catch {
                // Cancellation is not a failure, so it must not land the user on
                // a retry row. Back to `.idle` on the same page: the footer
                // reappearing asks for it again.
                guard !Task.isCancelled else {
                    paginationPublished = .idle(nextPage: page)
                    return
                }
                // Everything already loaded stays on screen. Only the footer
                // changes, into something the user can tap.
                paginationPublished = .failed(nextPage: page)
            }
        }
        // Assigned before the body can run: we are on the main actor and the
        // task cannot start until this function suspends, which it never does.
        nextPageTask = task
        return task
    }
}
