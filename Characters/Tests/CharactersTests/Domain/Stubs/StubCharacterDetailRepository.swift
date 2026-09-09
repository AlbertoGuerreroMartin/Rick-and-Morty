//
//  StubCharacterDetailRepository.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
@testable import Characters

actor StubCharacterDetailRepository: CharactersRepositoryContract {
    private let detail: CharacterDetailModel?
    private let error: (any Error)?
    private let links: HBOMaxLinks
    private let linksError: (any Error)?
    /// Bounded wait: a use case that stopped fetching both fails the assertion, not the suite.
    private let holdDetailUntilLinksStart: Bool
    private(set) var detailCallCount = 0
    private(set) var linksCallCount = 0
    private(set) var requestedIDs: [String] = []

    init(detail: CharacterDetailModel? = nil,
         error: (any Error)? = nil,
         links: HBOMaxLinks = .empty,
         linksError: (any Error)? = nil,
         holdDetailUntilLinksStart: Bool = false) {
        self.detail = detail
        self.error = error
        self.links = links
        self.linksError = linksError
        self.holdDetailUntilLinksStart = holdDetailUntilLinksStart
    }

    /// Not exercised here: this fake exists only to stand under the detail use case.
    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage {
        throw TestError()
    }

    func fetchCharacterDetail(id: String) async throws -> CharacterDetailModel {
        detailCallCount += 1
        requestedIDs.append(id)

        if holdDetailUntilLinksStart {
            for _ in 0..<10_000 {
                if linksCallCount > 0 { break }
                // The actor is reentrant, so suspending here lets the links call in.
                await Task.yield()
            }
        }

        if let error { throw error }
        guard let detail else { throw TestError() }
        return detail
    }

    func fetchHBOMaxLinks() async throws -> HBOMaxLinks {
        linksCallCount += 1
        if let linksError { throw linksError }
        return links
    }
}
