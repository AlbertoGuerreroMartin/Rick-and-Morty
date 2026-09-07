//
//  CharactersSectionEmptyReason.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

/// Why there is nothing to draw.
///
/// The two cases are told apart deliberately: "your search matched nothing" and
/// "we could not ask" look identical in an empty section, but one is answered
/// by widening the filter and the other by tapping Retry. Collapsing them would
/// offer the user the wrong button.
///
/// Shared by the list and the grid for the same reason as
/// `CharactersSectionFooter`: the empty state view is one view.
enum CharactersSectionEmptyReason: Equatable {
    /// The server answered, with nothing. `summary` is the filter in words, for
    /// copy that says *what* found nothing; `canClearFilters` is false when
    /// there is no filter to clear and the button would be a dead end.
    case noMatches(summary: String?, canClearFilters: Bool)
    case failed
}
