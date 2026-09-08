//
//  LocationsPage.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

/// One page of locations, plus the page number to ask for next (`nil` at the end).
struct LocationsPage: Sendable {
    let locations: [LocationModel]
    let nextPage: Int?
}
