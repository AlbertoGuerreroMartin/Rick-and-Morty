//
//  CharactersSectionFooter.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

/// What the last element of a results section is; shared by the list and grid sections' mappers.
enum CharactersSectionFooter: Equatable {
    /// A page is waiting; the footer's `.task` is what asks for it.
    case loadMore
    case loading
    case retry
    case none
}
