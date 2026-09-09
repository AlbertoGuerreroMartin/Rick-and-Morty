//
//  StubCharactersHBOMaxLinksRemoteDataSource.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
@testable import Characters

actor StubCharactersHBOMaxLinksRemoteDataSource: HBOMaxLinksRemoteDataSourceContract {
    private let result: Result<JustWatchShowEntity, any Error>
    private(set) var callCount = 0

    init(result: Result<JustWatchShowEntity, any Error> = .success(JustWatchShowEntity(seasons: nil))) {
        self.result = result
    }

    func fetchShowOffers(_ query: JustWatchShowOffersQuery) async throws -> JustWatchShowEntity {
        callCount += 1
        return try result.get()
    }
}
