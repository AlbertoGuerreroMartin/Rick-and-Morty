//
//  DiskStoreContract.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation

/// One file on disk, as seen by a caller that never learns which key wrote it.
///
/// `fileName` is the hashed, on-disk name: it is deliberately *not* the
/// identifier, because the hash is one-way. It is still enough to implement a
/// size cap or an expiry sweep, which only ever need to read a file, measure it
/// and possibly delete it — never to reconstruct the key that produced it.
public struct DiskStoreEntry: Sendable, Hashable {
    public let fileName: String
    /// Bytes the file occupies.
    public let size: Int
    public let modificationDate: Date

    public init(fileName: String, size: Int, modificationDate: Date) {
        self.fileName = fileName
        self.size = size
        self.modificationDate = modificationDate
    }
}

/// Raw bytes on disk, grouped by namespace. Nothing here knows about types,
/// lifetimes or expiry — that is ``CacheStoreContract``'s job, layered on top.
///
/// The split is what keeps both halves testable in isolation: a cache policy can
/// be tested against a spy store with no filesystem, and the filesystem details
/// can be tested without a single `Codable` type.
public protocol DiskStoreContract: Sendable {
    /// The stored bytes, or `nil` when nothing was written for `key`.
    /// A genuine I/O failure (permissions, corruption) propagates.
    func data(for key: CacheKey) async throws -> Data?

    func store(_ data: Data, for key: CacheKey) async throws

    func remove(_ key: CacheKey) async throws

    /// Drops the whole namespace. Removing a missing namespace is a no-op.
    func removeAll(in namespace: String) async throws

    /// Every namespace that currently exists on disk.
    ///
    /// Needed by sweeps that run at launch: a process that has just started has
    /// no idea which namespaces previous runs wrote, so it has to ask the disk.
    func namespaces() async throws -> [String]

    /// Per-file listing so callers can implement caps and sweeps: total size is
    /// the sum of `size`, and eviction order comes from `modificationDate`.
    /// A missing namespace lists as empty rather than throwing.
    func entries(in namespace: String) async throws -> [DiskStoreEntry]

    /// Reads back an entry produced by ``entries(in:)``. The only way to inspect
    /// a file's *contents* during a sweep, since the key cannot be recovered.
    func data(fileNamed fileName: String, in namespace: String) async throws -> Data?

    /// Deletes an entry produced by ``entries(in:)``.
    func remove(fileNamed fileName: String, in namespace: String) async throws
}
