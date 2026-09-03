//
//  CharactersListSectionMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine

enum CharactersListRenderModel {
    case visible([Character])
    case hidden
}

class CharactersListSectionMapper {
    typealias RenderModel = CharactersListRenderModel
    
    let viewModel: CharactersListSectionViewModelContract
    
    init(viewModel: CharactersListSectionViewModelContract) {
        self.viewModel = viewModel
    }
    
    func map() -> AnyPublisher<RenderModel, Never> {
        viewModel.loadingPublisher
            .combineLatest(viewModel.charactersPublisher)
            .map {
                guard !$0 else {
                    return .hidden
                }
                
                return .visible($1 ?? [])
            }.eraseToAnyPublisher()
    }
}
