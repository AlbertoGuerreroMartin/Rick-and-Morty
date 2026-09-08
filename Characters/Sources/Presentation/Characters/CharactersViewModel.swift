//
//  CharactersViewModel.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine
import Foundation
import Networking

@MainActor
final class CharactersViewModel: CharactersListSectionViewModelContract,
                                 CharactersGridSectionViewModelContract,
                                 CharactersFilterBarSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> {
        $loadingPublished.eraseToAnyPublisher()
    }

    var charactersPublisher: AnyPublisher<[CharacterModel]?, Never> {
        $charactersPublished.eraseToAnyPublisher()
    }

    var paginationPublisher: AnyPublisher<CharactersPaginationState, Never> {
        $paginationPublished.eraseToAnyPublisher()
    }

    var filterPublisher: AnyPublisher<CharactersFilter, Never> {
        $filterPublished.eraseToAnyPublisher()
    }

    var loadFailedPublisher: AnyPublisher<Bool, Never> {
        $loadFailedPublished.eraseToAnyPublisher()
    }

    let charactersUseCase: CharactersUseCaseContract

    /// Injectable so tests can collapse the debounce to zero.
    private let searchDebounce: Duration

    init(charactersUseCase: CharactersUseCaseContract,
         searchDebounce: Duration = .milliseconds(300)) {
        self.charactersUseCase = charactersUseCase
        self.searchDebounce = searchDebounce
    }

    @Published var loadingPublished = false
    @Published var charactersPublished: [CharacterModel]?
    /// Starts at `.end` so the footer stays hidden until the first page reports `info.next`.
    @Published var paginationPublished: CharactersPaginationState = .end
    @Published var filterPublished: CharactersFilter = .empty
    @Published var loadFailedPublished = false

    private var hasLoaded = false
    private var isFetching = false

    /// Bumped on every reload; a fetch applies its result only if its generation is still current.
    private var generation = 0

    private var nextPageTask: Task<Void, Never>?

    /// Internal, not private, so tests can await it.
    private(set) var reloadTask: Task<Void, Never>?

    private(set) var searchDebounceTask: Task<Void, Never>?

    func loadData() async {
        // `.task` refires on every return to the tab; only the first call does work.
        guard !hasLoaded, !isFetching else { return }

        isFetching = true
        defer { isFetching = false }

        await startReload(to: filterPublished).value
    }

    // MARK: - Search and filters

    /// Debounced: rickandmortyapi answers 429 to requests fired on every keystroke.
    func updateSearchText(_ text: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            // `.zero` still suspends, giving a superseded keystroke a chance to see it was cancelled.
            try? await Task.sleep(for: searchDebounce)
            guard !Task.isCancelled else { return }

            let target = filterPublished.with(name: text)
            guard target != filterPublished else { return }
            await startReload(to: target).value
        }
    }

    func apply(_ filter: CharactersFilter) {
        guard filter != filterPublished else { return }
        startReload(to: filter)
    }

    func clear(_ field: CharactersFilter.Field) {
        var filter = filterPublished
        filter.clear(field)
        apply(filter)
    }

    func clearAllFilters() {
        apply(filterPublished.clearingFields())
    }

    /// Unconditional, unlike `apply`: retrying the same filter is the point.
    func retryLoad() {
        startReload(to: filterPublished)
    }

    /// Reloads page 1 after an external cache clear. See `CacheClearedNotification`.
    func reloadFromScratch() async {
        searchDebounceTask?.cancel()
        reloadTask?.cancel()
        if let task = nextPageTask {
            task.cancel()
            await task.value
        }

        hasLoaded = false
        charactersPublished = nil
        paginationPublished = .end
        await startReload(to: filterPublished).value
    }

    @discardableResult
    private func startReload(to filter: CharactersFilter) -> Task<Void, Never> {
        reloadTask?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await reload(to: filter)
        }
        reloadTask = task
        return task
    }

    private func reload(to filter: CharactersFilter) async {
        // Bumped before awaiting: a page that lands after this sees a stale generation and drops it.
        generation += 1
        let reloadGeneration = generation

        if let task = nextPageTask {
            task.cancel()
            await task.value
        }
        guard reloadGeneration == generation else { return }

        filterPublished = filter
        loadingPublished = true
        paginationPublished = .end

        do {
            let page = try await charactersUseCase.fetchCharacters(filter: filter, page: 1)
            guard reloadGeneration == generation else { return }
            charactersPublished = page.characters
            paginationPublished = CharactersPaginationState(nextPage: page.nextPage)
            loadFailedPublished = false
            hasLoaded = true
            loadingPublished = false
        } catch {
            guard reloadGeneration == generation,
                  !Task.isCancelled,
                  !(error is CancellationError) else { return }
            charactersPublished = []
            paginationPublished = .end
            loadFailedPublished = true
            loadingPublished = false
        }
    }

    // MARK: - Pagination

    /// Task owned by the view model: SwiftUI cancels the footer's `.task` when the row
    /// scrolls off, but rickandmortyapi still counts an abandoned request against the rate limit.
    func loadNextPage() async {
        guard let task = nextPageTask ?? makeNextPageTask() else { return }
        await task.value
    }

    /// - Returns: the newly started task, or `nil` when there is nothing to load.
    private func makeNextPageTask() -> Task<Void, Never>? {
        let page: Int
        switch paginationPublished {
        case .idle(let nextPage), .failed(let nextPage):
            page = nextPage
        case .loading, .end:
            return nil
        }

        paginationPublished = .loading

        // Captured now: filterPublished may describe a different list by the time this resolves.
        let filter = filterPublished
        let requestGeneration = generation

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.nextPageTask = nil }

            do {
                let result = try await charactersUseCase.fetchCharacters(filter: filter, page: page)
                guard requestGeneration == self.generation else { return }
                charactersPublished = (charactersPublished ?? []) + result.characters
                paginationPublished = CharactersPaginationState(nextPage: result.nextPage)
            } catch {
                guard requestGeneration == self.generation else { return }
                guard !Task.isCancelled else {
                    paginationPublished = .idle(nextPage: page)
                    return
                }
                paginationPublished = .failed(nextPage: page)
            }
        }
        // Assigned before the task body runs: nothing suspends before this point.
        nextPageTask = task
        return task
    }
}
