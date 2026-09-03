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

    var charactersPublisher: AnyPublisher<[Character]?, Never> {
        $charactersPublished.eraseToAnyPublisher()
    }
    
    @Published var loadingPublished = false
    @Published var charactersPublished: [Character]?
    
    @MainActor
    func loadData() async {
        loadingPublished = true
        
        // TODO: Move to upper layers
        let query = CharactersQuery()
        self.charactersPublished = try? await GraphQLClient.rickAndMorty.execute(query)
            .result.results?.compactMap {
                guard let name = $0?.name else { return nil }
                return Character(name: name)
        }
        loadingPublished = false
    }
}
