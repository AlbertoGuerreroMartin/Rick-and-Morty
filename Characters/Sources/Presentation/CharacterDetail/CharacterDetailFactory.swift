//
//  CharacterDetailFactory.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import SwiftUI

/// The detail screen's composition root.
@MainActor
enum CharacterDetailFactory {
    static func build(dependencies: any CharactersDependencies,
                      id: String) -> some View {
        CharacterDetailScreen(
            makeGraph: { makeGraph(dependencies: dependencies, id: id) },
            makeSections: { graph in
                CharacterDetailHeaderSectionView(viewModel: graph.viewModel, mapper: graph.headerMapper)
                CharacterDetailInfoSectionView(mapper: graph.infoMapper)
                CharacterDetailEpisodesSectionView(mapper: graph.episodesMapper)
            }
        )
    }

    static func makeGraph(dependencies: any CharactersDependencies,
                          id: String) -> CharacterDetailScreenGraph {
        let entityMapper = CharacterEntityMapper()
        let detailMapper = CharacterDetailEntityMapper()
        let remoteDataSource = CharactersRemoteDataSource(client: dependencies.graphQLClient)
        let linksRemoteDataSource = HBOMaxLinksRemoteDataSource(client: dependencies.justWatchClient)
        let localDataSource = CharactersLocalDataSource(cacheStore: dependencies.cacheStore)
        let repository = CharactersRepository(remoteDataSource: remoteDataSource,
                                              hboMaxLinksRemoteDataSource: linksRemoteDataSource,
                                              localDataSource: localDataSource,
                                              mapper: entityMapper,
                                              detailMapper: detailMapper,
                                              linksMapper: HBOMaxLinksMapper())
        let useCase = CharacterDetailUseCase(repository: repository)
        let viewModel = CharacterDetailViewModel(id: id, characterDetailUseCase: useCase)
        return CharacterDetailScreenGraph(
            viewModel: viewModel,
            headerMapper: CharacterDetailHeaderSectionMapper(viewModel: viewModel),
            infoMapper: CharacterDetailInfoSectionMapper(viewModel: viewModel),
            episodesMapper: CharacterDetailEpisodesSectionMapper(viewModel: viewModel)
        )
    }
}
