//
//  CacheKey.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation

/// Addresses one cached value.
///
/// Two parts rather than one string because the two are used differently:
/// `namespace` is a *directory* on disk, so a feature can wipe or measure
/// everything it owns (`removeAll(in:)`, `entries(in:)`) without knowing which
/// identifiers it wrote; `identifier` only ever has to be unique inside its
/// namespace, which lets each caller derive it from whatever it already has —
/// a query, a URL — instead of inventing a global naming scheme.
public struct CacheKey: Hashable, Sendable {
    public let namespace: String
    public let identifier: String

    public init(namespace: String, identifier: String) {
        self.namespace = namespace
        self.identifier = identifier
    }
}
