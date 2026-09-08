//
//  DiskStoreContract.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation

/// One file on disk, as seen by a caller that never learns which key wrote it. `fileName` is
/// the hashed on-disk name (one-way) — enough to measure or delete a file but not recover its key.
public struct DiskStoreEntry: Sendable, Hashable {
    public let fileName: String
    public let size: Int
    public let modificationDate: Date

    public init(fileName: String, size: Int, modificationDate: Date) {
        self.fileName = fileName
        self.size = size
        self.modificationDate = modificationDate
    }
}

/// Raw bytes on disk, grouped by namespace; type/lifetime/expiry logic lives in
/// ``CacheStoreContract`` on top. Split for testability: a cache policy can be tested against a
/// spy store, filesystem details without a single `Codable` type.
public protocol DiskStoreContract: Sendable {
    /// `nil` when nothing was written for `key`; a genuine I/O failure propagates.
    func data(for key: CacheKey) async throws -> Data?

    func store(_ data: Data, for key: CacheKey) async throws

    func remove(_ key: CacheKey) async throws

    /// Drops the whole namespace. Removing a missing namespace is a no-op.
    func removeAll(in namespace: String) async throws

    /// Every namespace on disk — needed by launch-time sweeps, which have no record of what a
    /// previous run wrote.
    func namespaces() async throws -> [String]

    /// Per-file listing for caps/sweeps: total size sums `size`, eviction order comes from
    /// `modificationDate`. A missing namespace lists as empty rather than throwing.
    func entries(in namespace: String) async throws -> [DiskStoreEntry]

    /// Reads a file's contents during a sweep, since the key can't be recovered from `fileName`.
    func data(fileNamed fileName: String, in namespace: String) async throws -> Data?

    /// Deletes an entry produced by ``entries(in:)``.
    func remove(fileNamed fileName: String, in namespace: String) async throws
}
