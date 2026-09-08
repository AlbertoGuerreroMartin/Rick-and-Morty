//
//  CharactersSectionEmptyReason.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

/// Why there is nothing to draw. Kept apart from `.failed` because one is answered by
/// widening the filter and the other by tapping Retry.
enum CharactersSectionEmptyReason: Equatable {
    /// `summary` is the filter in words; `canClearFilters` is false when there is none to clear.
    case noMatches(summary: String?, canClearFilters: Bool)
    case failed
}
