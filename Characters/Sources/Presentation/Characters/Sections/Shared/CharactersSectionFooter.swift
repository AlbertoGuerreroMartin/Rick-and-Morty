//
//  CharactersSectionFooter.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

/// What the last element of a results section is, once the items above it are
/// drawn.
///
/// Shared by the list and the grid: the two sections have their own mappers,
/// but they end in the same footer, and the footer *view* is shared, so the
/// value it draws has to be one type. The view never sees
/// `CharactersPaginationState`: the difference between `.idle` and `.loading`
/// is a trigger detail, and both draw the same spinner.
enum CharactersSectionFooter: Equatable {
    /// Nothing loading yet, and there is a page waiting — the footer's `.task`
    /// is what asks for it.
    case loadMore
    case loading
    case retry
    case none
}
