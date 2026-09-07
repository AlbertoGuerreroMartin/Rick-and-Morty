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
    /// Drops every cached image. Nothing in the app calls this on its own —
    /// entries never go stale, so there is no correctness reason to — but a
    /// developer tearing down a caching bug needs a cold start on demand, and
    /// deleting the container is a heavier way to get one.
    func removeAll() async throws
}

/// Persists downloaded image *bytes* so a relaunch costs no requests.
///
/// Two decisions worth spelling out:
///
/// - **The original encoded bytes go to disk, never the decoded bitmap.** An
///   avatar here is a 300x300 JPEG — 10 to 30 KB. Decoded, the same image is
///   360 KB, more than ten times the size, and it would still have to be
///   re-encoded or memory-mapped to be useful. Bytes on disk, pixels in memory.
/// - **Nothing expires.** These URLs end in a content path that never serves
///   different bytes, so an entry cannot go stale — there is nothing to
///   revalidate and no lifetime worth guessing. That is exactly the case
///   ``CacheStoreContract`` is *not* for, which is why this sits directly on
///   ``DiskStoreContract``: no envelope, no dates, just the file.
///
/// - Note: the store lives under `Library/Caches`, so the OS may purge it. Every
///   entry is re-downloadable, so a purge costs latency and nothing else.
public actor ImageDiskCache: ImageDiskCacheContract {

    /// One directory for every image, independent of which feature asked for it.
    private static let namespace = "images"

    private let diskStore: any DiskStoreContract
    private let capacity: Int
    private var hasSwept = false

    /// - Parameter capacity: a safety net, not a working limit. The whole Rick
    ///   and Morty catalogue is roughly 800 avatars at ~20 KB — about 16 MB, an
    ///   order of magnitude under the default. The cap exists so a future screen
    ///   showing large artwork, or a pathological URL set, cannot quietly fill
    ///   the user's disk; in normal use it never fires.
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

    /// One namespace, so this is one directory removal rather than a walk over
    /// URLs the cache never recorded — the file names are hashes and cannot be
    /// turned back into the URLs that produced them.
    public func removeAll() async throws {
        try await diskStore.removeAll(in: Self.namespace)
    }

    /// Trims the namespace back under 75% of the cap, oldest first.
    ///
    /// Once per process, on first use, rather than on every write: measuring the
    /// directory means stat-ing every file, which is far too much work to do per
    /// image, and the cap is a bound on unbounded growth across launches rather
    /// than a per-write invariant. Trimming to 75% instead of exactly to the cap
    /// keeps a single oversized launch from sweeping again immediately.
    ///
    /// Oldest-by-modification-date, because for immutable content the least
    /// recently *written* entry is the best available stand-in for the least
    /// recently wanted one — the file system is not going to tell us more than
    /// that without a read of its own.
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
