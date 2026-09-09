//
//  StubCharactersRemoteDataSource.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
@testable import Characters

actor StubCharactersRemoteDataSource: CharactersRemoteDataSourceContract {
    private let result: Result<CharactersPageEntity, any Error>
    private let detailResult: Result<CharacterDetailEntity, any Error>
    private(set) var callCount = 0
    private(set) var detailCallCount = 0
    private(set) var lastQuery: CharactersQuery?
    private(set) var lastDetailQuery: CharacterDetailQuery?

    init(result: Result<CharactersPageEntity, any Error>,
         detailResult: Result<CharacterDetailEntity, any Error> = .failure(TestError())) {
        self.result = result
        self.detailResult = detailResult
    }

    func fetchCharactersPage(_ query: CharactersQuery) async throws -> CharactersPageEntity {
        callCount += 1
        lastQuery = query
        return try result.get()
    }

    func fetchCharacterDetail(_ query: CharacterDetailQuery) async throws -> CharacterDetailEntity {
        detailCallCount += 1
        lastDetailQuery = query
        return try detailResult.get()
    }
}
