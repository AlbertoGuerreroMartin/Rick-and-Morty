//
//  LocationsPaginationState.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

/// Where the carousel stands with respect to more locations. Carries the page number
/// itself so a retry asks for the page that actually failed rather than guessing.
enum LocationsPaginationState: Equatable, Sendable {
    case idle(nextPage: Int)
    case loading
    case failed(nextPage: Int)
    case end

    /// `nextPage == nil` means the API says this was the last page: `.end`, not an error.
    init(nextPage: Int?) {
        self = nextPage.map { .idle(nextPage: $0) } ?? .end
    }
}
