//
//  CacheStoreContract.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation

/// A cached value with the dates that decide whether it is still usable. Handed back even when
/// expired (`isExpired` is a plain flag, not a `nil`), so a repository can render stale data on
/// a network failure instead of an empty screen.
public struct CacheEntry<Value: Sendable>: Sendable {
    public let value: Value
    public let storedAt: Date
    public let expiresAt: Date
    public let isExpired: Bool

    public init(value: Value, storedAt: Date, expiresAt: Date, isExpired: Bool) {
        self.value = value
        self.storedAt = storedAt
        self.expiresAt = expiresAt
        self.isExpired = isExpired
    }
}

/// `Codable` values with a lifetime, layered over a ``DiskStoreContract``. Callers depend on
/// this protocol rather than ``CodableCacheStore``, so a feature can be tested against an
/// in-memory fake.
public protocol CacheStoreContract: Sendable {
    /// `nil` when nothing is stored, or what's stored no longer decodes (treated as a miss).
    func entry<Value: Codable & Sendable>(for key: CacheKey, as type: Value.Type) async throws -> CacheEntry<Value>?

    /// - Parameter lifetime: seconds from now until the value is considered stale.
    func store<Value: Codable & Sendable>(_ value: Value, for key: CacheKey, lifetime: TimeInterval) async throws

    func remove(_ key: CacheKey) async throws

    /// Drops every entry in `namespace`, fresh or not. A missing namespace is a no-op.
    func removeAll(in namespace: String) async throws

    /// Deletes every entry whose lifetime has run out, across all namespaces. Files it can't
    /// recognize as its own are left untouched — the disk store may be shared with other layers.
    func removeExpired() async throws
}
