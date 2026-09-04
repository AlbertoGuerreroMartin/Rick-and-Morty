//
//  CharactersFactory.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import SwiftUI

@MainActor
public enum CharactersFactory {
    /// Returns a screen *description*, not a built graph: the closures below are
    /// only invoked once per screen identity (see `CharactersScreen`), so the
    /// parent re-evaluating its body no longer rebuilds — and throws away — the
    /// view model.
    public static func build(dependencies: any CharactersDependencies) -> some View {
        CharactersScreen(
            makeGraph: { makeGraph(dependencies: dependencies) },
            makeSection: { graph in
                CharactersListSectionView(mapper: graph.listMapper)
            }
        )
    }

    /// The feature's composition root: every layer is wired here by constructor
    /// injection, from the infrastructure the app provides down to the screen.
    static func makeGraph(dependencies: any CharactersDependencies) -> CharactersScreenGraph {
        let entityMapper = CharacterEntityMapper()
        let remoteDataSource = CharactersRemoteDataSource(client: dependencies.graphQLClient,
                                                          mapper: entityMapper)
        let repository = CharactersRepository(remoteDataSource: remoteDataSource)
        let useCase = CharactersUseCase(repository: repository)
        let viewModel = CharactersViewModel(charactersUseCase: useCase)
        let listMapper = CharactersListSectionMapper(viewModel: viewModel)
        return CharactersScreenGraph(viewModel: viewModel, listMapper: listMapper)
    }
}
