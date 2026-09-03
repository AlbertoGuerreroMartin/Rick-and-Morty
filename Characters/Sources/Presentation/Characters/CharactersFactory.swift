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
        let viewModel = CharactersViewModel()
        let charactersListSection = buildCharactersListSection(viewModel: viewModel)
        return CharactersScreen(viewModel: viewModel,
                                charactersListSection: charactersListSection)
    }
    
    static func buildCharactersListSection(viewModel: any CharactersListSectionViewModelContract) -> CharactersListSectionView {
        let mapper = CharactersListSectionMapper(viewModel: viewModel)
        return CharactersListSectionView(mapper: mapper)
    }
}
