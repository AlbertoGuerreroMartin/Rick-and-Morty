//
//  ImageDiskCache.swift
//  DesignSystem
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation
import Storage

/// The encoded bytes of a remote image, keyed by its URL.
public protocol ImageDiskCacheContract: Sendable {
    func data(for url: URL) async throws -> Data?
    func store(_ data: Data, for url: URL) async throws
    /// Nothing calls this in normal use — entries never go stale — but it gives a cold start
    /// on demand while debugging a caching issue.
    func removeAll() async throws
}

/// Persists downloaded image bytes (encoded, not the decoded bitmap) so a relaunch costs no
/// requests. Nothing expires: these URLs are content-addressed and never serve different bytes,
/// so this sits directly on ``DiskStoreContract`` rather than ``CacheStoreContract``.
///
/// - Note: lives under `Library/Caches`; the OS may purge it, costing only a re-download.
public actor ImageDiskCache: ImageDiskCacheContract {

    private static let namespace = "images"

    private let diskStore: any DiskStoreContract
    private let capacity: Int
    private var hasSwept = false

    /// - Parameter capacity: a safety net, not a working limit — normal use is far under it;
    ///   guards against a pathological URL set filling the user's disk.
    public init(diskStore: any DiskStoreContract, capacity: Int = 128 * 1_024 * 1_024) {
        self.diskStore = diskStore
        self.capacity = capacity
    }

    public func data(for url: URL) async throws -> Data? {
        await sweepIfNeeded()
        return try await diskStore.data(for: key(for: url))
    }

    public func store(_ data: Data, for url: URL) async throws {
        await sweepIfNeeded()
        try await diskStore.store(data, for: key(for: url))
    }

    /// One directory removal: file names are hashes and can't be turned back into URLs to
    /// remove selectively.
    public func removeAll() async throws {
        try await diskStore.removeAll(in: Self.namespace)
    }

    /// Trims the namespace to 75% of the cap, oldest-by-modification-date first. Runs once per
    /// process, on first use — stat-ing every file on every write would be too costly.
    private func sweepIfNeeded() async {
        guard !hasSwept else { return }
        hasSwept = true

        guard let entries = try? await diskStore.entries(in: Self.namespace) else { return }
        var total = entries.reduce(0) { $0 + $1.size }
        guard total > capacity else { return }

        let target = capacity * 3 / 4
        for entry in entries.sorted(by: { $0.modificationDate < $1.modificationDate }) {
            guard total > target else { return }
            try? await diskStore.remove(fileNamed: entry.fileName, in: Self.namespace)
            total -= entry.size
        }
    }

    private func key(for url: URL) -> CacheKey {
        CacheKey(namespace: Self.namespace, identifier: url.absoluteString)
    }
}
