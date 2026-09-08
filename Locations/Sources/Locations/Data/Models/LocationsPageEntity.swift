//
//  LocationsPageEntity.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Networking

/// One page of locations exactly as the server sent it: `info` plus `results`.
///
/// This — not `[LocationModel]` — is what gets written to the cache. Caching the
/// *entity* keeps the stored bytes a faithful copy of the wire format, so the
/// mapper stays a pure, always-applied transformation rather than something that
/// ran once, months ago, against rules that have since changed. It also keeps
/// `info.next` around, which is what seeds the pagination state and a flat model
/// list has nowhere to put.
typealias LocationsPageEntity = GraphQLPageResponse<LocationEntity>
