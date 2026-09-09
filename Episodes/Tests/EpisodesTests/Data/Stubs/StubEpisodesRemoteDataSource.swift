//
//  StubEpisodesRemoteDataSource.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
@testable import Episodes

/// Keyed on the page number, the only handle a test has since the repository builds the query.
actor StubEpisodesRemoteDataSource: EpisodesRemoteDataSourceContract {
    private let pages: [Int: Result<EpisodesPageEntity, any Error>]
    private(set) var requestedPages: [Int] = []

    var callCount: Int { requestedPages.count }

    init(pages: [Int: Result<EpisodesPageEntity, any Error>]) {
        self.pages = pages
    }

    func fetchEpisodesPage(_ query: EpisodesQuery) async throws -> EpisodesPageEntity {
        let page = query.page ?? 1
        requestedPages.append(page)
        guard let result = pages[page] else { throw TestError() }
        return try result.get()
    }
}
