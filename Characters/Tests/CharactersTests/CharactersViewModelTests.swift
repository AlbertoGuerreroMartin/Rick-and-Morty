//
//  CharactersViewModelTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Foundation
import Testing
@testable import Characters

/// Every layer takes its collaborator through its initializer, so a test can
/// stand a view model on a stub use case with no container or registry setup.
@MainActor
struct CharactersViewModelTests {
    @Test func loadDataPublishesCharactersFromUseCase() async {
        let rick = CharacterModel(id: "1",
                                  name: "Rick Sanchez",
                                  status: .alive,
                                  species: "Human",
                                  image: URL(string: "https://example.com/rick.jpeg")!,
                                  location: CharacterLocation(name: "Citadel of Ricks", dimension: nil))
        let viewModel = CharactersViewModel(charactersUseCase: StubCharactersUseCase(result: .success([rick])))

        await viewModel.loadData()

        #expect(viewModel.charactersPublished?.map(\.name) == ["Rick Sanchez"])
        #expect(viewModel.loadingPublished == false)
    }

    @Test func loadDataPublishesEmptyListWhenUseCaseFails() async {
        let viewModel = CharactersViewModel(charactersUseCase: StubCharactersUseCase(result: .failure(StubError())))

        await viewModel.loadData()

        #expect(viewModel.charactersPublished?.isEmpty == true)
        #expect(viewModel.loadingPublished == false)
    }
}

private struct StubError: Error {}

private struct StubCharactersUseCase: CharactersUseCaseContract {
    let result: Result<[CharacterModel], StubError>

    func fetchCharacters() async throws -> [CharacterModel] {
        try result.get()
    }
}
