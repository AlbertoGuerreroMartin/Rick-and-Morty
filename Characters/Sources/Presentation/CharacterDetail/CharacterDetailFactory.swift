//
//  CharacterDetailFactory.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import SwiftUI

/// The detail screen's composition root.
///
/// `internal`, unlike `CharactersFactory`: nothing outside this module pushes a
/// character detail. It is reached from the list's `navigationDestination`, and
/// the route value is the only thing that crosses between them — so the app
/// never learns that this screen exists, and adding a second way in later is a
/// change inside the feature.
@MainActor
enum CharacterDetailFactory {
    /// Returns a screen *description*, not a built graph: the closures below are
    /// only invoked once per screen identity (see `CharacterDetailScreen`), so
    /// the navigation stack re-evaluating its body no longer rebuilds — and
    /// throws away — the view model, which on a pushed screen would restart the
    /// fetch on every scroll of the list behind it.
    static func build(dependencies: any CharactersDependencies,
                      route: CharacterDetailRoute) -> some View {
        CharacterDetailScreen(
            makeGraph: { makeGraph(dependencies: dependencies, id: route.id) },
            makeSections: { graph in
                // Three sections in one `VStack`, in the order they are read.
                // The header owns the spinner and the failure, so the two below
                // it simply are not there until a character has landed.
                CharacterDetailHeaderSectionView(viewModel: graph.viewModel, mapper: graph.headerMapper)
                CharacterDetailInfoSectionView(mapper: graph.infoMapper)
                CharacterDetailEpisodesSectionView(mapper: graph.episodesMapper)
            }
        )
    }

    /// Every layer is wired here by constructor injection, from the
    /// infrastructure the app provides down to the three mappers.
    static func makeGraph(dependencies: any CharactersDependencies,
                          id: String) -> CharacterDetailScreenGraph {
        let entityMapper = CharacterEntityMapper()
        let detailMapper = CharacterDetailEntityMapper()
        let remoteDataSource = CharactersRemoteDataSource(client: dependencies.graphQLClient)
        // The one place the two clients are told apart on this screen.
        // Everything downstream takes a contract, so nothing else in the feature
        // can hand a JustWatch query to rickandmortyapi.
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
