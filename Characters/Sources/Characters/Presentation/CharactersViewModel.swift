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
//        try? await Task.sleep(nanoseconds: 3_000_000_000)
//        self.charactersPublished = [
//            .init(name: "Character 1"),
//            .init(name: "Character 2"),
//            .init(name: "Character 3"),
//            .init(name: "Character 4"),
//            .init(name: "Character 5"),
//            .init(name: "Character 6")
//        ]
        loadingPublished = false
    }
}
