//
//  LocationsSectionEmptyReason.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

/// Why there is nothing to draw. Kept distinct because only `.failed` gets a Retry button.
enum LocationsSectionEmptyReason: Equatable {
    case noLocations
    case failed
}
