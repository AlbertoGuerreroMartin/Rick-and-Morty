//
//  LocationsSectionEmptyReason.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

/// Why there is nothing to draw.
///
/// The two cases are told apart deliberately: "there are no locations" and "we
/// could not ask" look identical on an empty carousel, but only one of them is
/// answered by a button. Collapsing them would either offer a Retry for an
/// answer that was correct, or withhold one from a failure the user could fix.
enum LocationsSectionEmptyReason: Equatable {
    /// The API answered, and answered with nothing.
    case noLocations
    case failed
}
