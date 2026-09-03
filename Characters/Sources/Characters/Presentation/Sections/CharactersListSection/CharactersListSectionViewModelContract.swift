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

protocol CharactersListSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> { get }
    var charactersPublisher: AnyPublisher<[Character]?, Never> { get }
}
