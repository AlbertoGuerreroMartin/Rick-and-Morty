//
//  CharactersViewModel.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine
import Networking

class CharactersViewModel: CharactersListSectionViewModelContract {
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
    
    @MainActor
    func loadData() async {
        loadingPublished = true
        self.charactersPublished = try? await charactersUseCase.fetchCharacters()
        loadingPublished = false
    }
}
