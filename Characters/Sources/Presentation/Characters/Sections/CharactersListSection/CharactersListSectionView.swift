//
//  CharactersListSectionView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine
import SwiftUI

struct CharactersListSectionView: View {
    private let renderModelPublisher: AnyPublisher<CharactersListRenderModel, Never>
    
    @State var renderModel: CharactersListRenderModel = .hidden
    
    init(mapper: CharactersListSectionMapper) {
        self.renderModelPublisher = mapper.renderModelPublisher()
    }
    
    var body: some View {
        content
            .onReceive(renderModelPublisher) {
                renderModel = $0
            }
    }
    
    @ViewBuilder
    var content: some View {
        switch renderModel {
        case .visible(let characters):
            charactersList(characters: characters)
        case .hidden:
            ProgressView()
        }
    }
    
    @ViewBuilder
    func charactersList(characters: [CharacterModel]) -> some View {
        List(characters, id: \.name) { character in
            Text(character.name)
        }
    }
}
