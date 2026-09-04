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
        List(characters, id: \.id) { character in
            characterRow(character: character)
        }
    }
    
    @ViewBuilder
    func characterRow(character: CharacterModel) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: character.image) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(character.name)
                    .font(.headline)
                HStack(spacing: 5) {
                    Circle()
                        .fill(character.status.color)
                        .frame(width: 7, height: 7)
                    Text("\(character.status.rawValue.capitalized) · \(character.species)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                let dimension = character.location.dimension.flatMap { "(\($0))" } ?? ""
                Text("\(character.location.name) \(dimension)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)

    }
}
