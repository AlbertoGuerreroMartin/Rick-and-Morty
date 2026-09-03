//
//  CharactersListSectionViewModelContract.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine

struct Character {
    let name: String
}

// Main-actor isolated: the conforming view models, the mapper and the section
// views all live on the main actor, and `@Published` projected values can only
// be read from the view model's own isolation domain.
@MainActor
protocol CharactersListSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }
    var charactersPublisher: AnyPublisher<[CharacterModel]?, Never> { get }
}
