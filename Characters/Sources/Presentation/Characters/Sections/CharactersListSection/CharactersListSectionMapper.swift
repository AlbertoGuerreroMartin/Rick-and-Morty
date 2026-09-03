//
//  CharactersListSectionMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine
import Core

enum CharactersListRenderModel {
    case visible([CharacterModel])
    case hidden
}

protocol CharactersListSectionMapperContract: SectionMapperContract {}

@MainActor
final class CharactersListSectionMapper: CharactersListSectionMapperContract {
    typealias ViewModel = CharactersListSectionViewModelContract
    typealias RenderModel = CharactersListRenderModel
    
    struct DataModel {
        let isLoading: Bool
        let characters: [CharacterModel]?
    }
    
    let viewModel: ViewModel
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    func dataPublisher(_ viewModel: ViewModel) -> AnyPublisher<DataModel, Never> {
        viewModel.loadingPublisher
            .combineLatest(viewModel.charactersPublisher)
            .map { DataModel(isLoading: $0, characters: $1) }
            .eraseToAnyPublisher()
    }
    
    func mapToRenderModel(_ data: DataModel) -> CharactersListRenderModel {
        guard !data.isLoading else {
            return .hidden
        }
        
        return .visible(data.characters ?? [])
    }
}
