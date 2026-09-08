//
//  LocationModel.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation

/// One location, in domain terms.
///
/// `type` and `dimension` are optional and the other two are not, which is the
/// whole difference between what the screen can draw and what it merely might:
/// the carousel needs an identity and a name for every circle it lays out, while a
/// place with no recorded type is simply a place with one line less in the
/// detail below.
///
/// The `id` is parsed and carried but never shown. It is what the selection is
/// published as — the view model publishes an id, not an index, so a page
/// landing underneath the focus cannot silently re-point the detail at a
/// different location — and it is what `ForEach` keys the circles on.
struct LocationModel: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    /// What kind of place it is, e.g. `Planet`, `Space station`, or the API's
    /// own literal `"unknown"`, which is kept verbatim. `nil` means the API has
    /// no record at all, and the detail draws no row for it.
    let type: String?
    /// The dimension it sits in, on the same terms as `type`.
    let dimension: String?
    let residents: [LocationResidentModel]
}

/// A character as a location knows one: something to draw and something to key
/// it on.
///
/// The `id` is not used to draw anything today. It is kept because the resident
/// strip is the obvious place for a tap to open a character, and a strip already
/// keyed on the id turns that into a one-line change rather than a trip back
/// through the entity, the mapper and the query.
struct LocationResidentModel: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let image: URL
}
