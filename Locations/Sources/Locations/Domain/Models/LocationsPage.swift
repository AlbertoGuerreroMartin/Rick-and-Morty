//
//  LocationsPage.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

/// One page of locations, in domain terms.
///
/// The repository returns this rather than a bare `[LocationModel]` because
/// `nextPage` is the only thing that says whether there is more to load, and it
/// exists on the wire (`info.next`). Dropping it at the data layer would mean
/// re-deriving pagination from a count later, or a second request just to find
/// out there is nothing left.
struct LocationsPage: Sendable {
    let locations: [LocationModel]
    /// The page number to ask for next, or `nil` at the end of the list.
    let nextPage: Int?
}
