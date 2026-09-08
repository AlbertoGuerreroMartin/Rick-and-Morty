//
//  LocationsPageEntity.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Networking

/// One page of locations as the server sent it. Cached as-is (not `[LocationModel]`) so the
/// mapper always runs against current rules, and `info.next` survives to seed pagination.
typealias LocationsPageEntity = GraphQLPageResponse<LocationEntity>
