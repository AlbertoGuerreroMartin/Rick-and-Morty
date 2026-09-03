//
//  CharactersFactory.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import SwiftUI

// TODO: Handle actors properly
@MainActor
public class CharactersFactory {
    public static func build() -> some View {
        // TODO: Design a Dependency Injection system
        let remoteDataSource = CharactersRemoteDataSource()
        let repository = CharactersRepository(remoteDataSource: remoteDataSource)
        let useCase = CharactersUseCase(repository: repository)
        let viewModel = CharactersViewModel(charactersUseCase: useCase)
        let charactersListSection = buildCharactersListSection(viewModel: viewModel)
        return CharactersScreen(viewModel: viewModel,
                                charactersListSection: charactersListSection)
    }
    
    static func buildCharactersListSection(viewModel: any CharactersListSectionViewModelContract) -> CharactersListSectionView {
        let mapper = CharactersListSectionMapper(viewModel: viewModel)
        return CharactersListSectionView(mapper: mapper)
    }
}
