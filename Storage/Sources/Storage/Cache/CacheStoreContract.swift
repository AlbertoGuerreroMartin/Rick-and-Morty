//
//  CacheStoreContract.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation

/// A cached value together with the dates that decide whether it is still
/// usable.
///
/// The entry is handed back even when it is expired, and `isExpired` is a plain
/// flag rather than the store silently returning `nil`. That is what makes
/// stale-while-error possible: a repository that cannot reach the network still
/// has yesterday's page in its hand and can choose to render it instead of an
/// empty screen. A store that hid expired entries would take that decision away
/// from the only layer that knows whether stale data is acceptable.
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

/// `Codable` values with a lifetime, layered over a ``DiskStoreContract``.
///
/// Callers depend on this protocol rather than on ``CodableCacheStore``, so a
/// feature can be tested against an in-memory fake and the app can swap the
/// implementation without touching a single call site.
public protocol CacheStoreContract: Sendable {
    /// The entry for `key`, or `nil` when nothing is stored — or when what is
    /// stored can no longer be decoded, which is treated as a miss rather than
    /// an error. See ``CodableCacheStore``.
    func entry<Value: Codable & Sendable>(for key: CacheKey, as type: Value.Type) async throws -> CacheEntry<Value>?

    /// - Parameter lifetime: seconds from now until the value is considered stale.
    func store<Value: Codable & Sendable>(_ value: Value, for key: CacheKey, lifetime: TimeInterval) async throws

    func remove(_ key: CacheKey) async throws

    /// Drops every entry in `namespace`, fresh or not. A missing namespace is a
    /// no-op. This is a feature wiping its own cache — it never crosses into
    /// another namespace, so nothing a caller does here can touch the images.
    func removeAll(in namespace: String) async throws

    /// Deletes every entry whose lifetime has run out, across all namespaces.
    /// Cheap enough to run at launch: it reads only each file's date header.
    /// Files it cannot recognise as its own are left untouched — the underlying
    /// disk store may be shared with layers that write raw bytes.
    func removeExpired() async throws
}
