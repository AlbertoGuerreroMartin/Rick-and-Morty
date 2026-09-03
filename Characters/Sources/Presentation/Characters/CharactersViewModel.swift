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
    
    let charactersUseCase: CharactersUseCaseContract
    
    init(charactersUseCase: CharactersUseCaseContract) {
        self.charactersUseCase = charactersUseCase
    }
    
    @Published var loadingPublished = false
    @Published var charactersPublished: [CharacterModel]?

    private var hasLoaded = false
    private var isFetching = false

    func loadData() async {
        // `.task` is bound to the view's appear/disappear lifetime, so it fires
        // again on every return to the tab. Only the first one does any work.
        guard !hasLoaded, !isFetching else { return }

        isFetching = true
        loadingPublished = true
        defer { isFetching = false }

        do {
            charactersPublished = try await charactersUseCase.fetchCharacters()
            hasLoaded = true
            loadingPublished = false
        } catch {
            // A cancelled fetch (leaving the tab mid-load) keeps the loading
            // state untouched so the next appear retries, instead of falling
            // through to an empty list.
            guard !Task.isCancelled else { return }
            charactersPublished = []
            loadingPublished = false
        }
    }
}
