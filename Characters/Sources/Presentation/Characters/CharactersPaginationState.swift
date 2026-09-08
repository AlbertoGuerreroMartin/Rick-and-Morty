//
//  CharactersPaginationState.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

/// Where the list stands with respect to more characters; carries the page number so `.failed` can retry it.
enum CharactersPaginationState: Equatable, Sendable {
    case idle(nextPage: Int)
    case loading
    case failed(nextPage: Int)
    case end

    /// `nextPage == nil` means the API had no further page, i.e. `.end`, not an error.
    init(nextPage: Int?) {
        self = nextPage.map { .idle(nextPage: $0) } ?? .end
    }
}
