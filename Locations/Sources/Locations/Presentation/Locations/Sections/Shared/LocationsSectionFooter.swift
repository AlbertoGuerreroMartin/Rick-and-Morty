//
//  LocationsSectionFooter.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

/// What the last stop on the carousel is. Drops the page number `LocationsPaginationState`
/// carries: the view has no use for it, and `.idle`/`.loading` both draw the same spinner.
enum LocationsSectionFooter: Equatable {
    case loadMore
    case loading
    case retry
    case none
}
