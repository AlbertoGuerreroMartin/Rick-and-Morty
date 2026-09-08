//
//  CacheKey.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation

/// Addresses one cached value. Two parts, not one string: `namespace` is a directory on disk
/// (so a feature can wipe/measure everything it owns without knowing its identifiers);
/// `identifier` need only be unique within it.
public struct CacheKey: Hashable, Sendable {
    public let namespace: String
    public let identifier: String

    public init(namespace: String, identifier: String) {
        self.namespace = namespace
        self.identifier = identifier
    }
}
