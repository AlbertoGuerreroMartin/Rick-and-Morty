//
//  CharactersPaginationState.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

/// Where the list stands with respect to *more* characters.
///
/// It deliberately carries the page number instead of leaving it in a separate
/// property: "there is more to load" and "which page is next" are the same fact,
/// and splitting them lets them disagree — a `nextPage` left over after the end,
/// or a retry that has forgotten which page failed. `.failed` keeps the number
/// precisely so the retry asks for the page that failed rather than guessing.
enum CharactersPaginationState: Equatable, Sendable {
    /// Nothing in flight, and `nextPage` is waiting to be asked for.
    case idle(nextPage: Int)
    /// A page request is in flight.
    case loading
    /// `nextPage` failed and can be retried.
    case failed(nextPage: Int)
    /// The API said there is no page after the last one we hold.
    case end

    /// Seeds the state from a page that just landed.
    ///
    /// - Note: `nextPage == nil` is the API telling us this was the last page,
    ///   so the absence of a number is `.end` rather than an error.
    init(nextPage: Int?) {
        self = nextPage.map { .idle(nextPage: $0) } ?? .end
    }
}
