//
//  LocationModel.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation

/// One location, in domain terms. `id` and `name` are required; `type`/`dimension` are not.
/// Selection is published by `id`, not index, so a page load can't silently re-point the detail.
struct LocationModel: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    /// `"unknown"` is a real API value and kept verbatim; `nil` means no record at all.
    let type: String?
    let dimension: String?
    let residents: [LocationResidentModel]
}

struct LocationResidentModel: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let status: LocationResidentStatus
    let species: String
    let image: URL
}

enum LocationResidentStatus: String, Sendable, Hashable, CaseIterable {
    case alive
    case dead
    case unknown

    init?(rawValue: String) {
        // API sends mixed casing; unrecognized values fall back to .unknown.
        switch rawValue.lowercased() {
        case "alive": self = .alive
        case "dead": self = .dead
        default: self = .unknown
        }
    }
}
