//
//  CodableCacheStore.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation

/// The default ``CacheStoreContract``: JSON envelopes on a ``DiskStoreContract``.
///
/// Every value is wrapped in an ``Envelope`` before it is written, so the dates
/// travel with the payload in one file. The alternative — a sidecar index of
/// expiry dates — needs its own write, its own corruption story, and goes out of
/// sync the moment the OS purges a file from under it. One self-describing file
/// per key has none of those failure modes.
///
/// An actor: the in-memory layer is mutable state shared by every caller.
public actor CodableCacheStore: CacheStoreContract {

    /// What actually lands on disk.
    private struct Envelope<Value: Codable & Sendable>: Codable, Sendable {
        let storedAt: Date
        let expiresAt: Date
        let value: Value
    }

    /// The date fields of an ``Envelope`` with `value` left undecoded.
    ///
    /// `removeExpired` runs over every file in the cache and only needs to know
    /// whether each one is stale. Decoding through this instead of the full
    /// envelope means the sweep never has to know the value's type — which it
    /// could not, the files are type-erased on disk — and never pays to
    /// materialise a payload it is about to delete.
    private struct EnvelopeHeader: Decodable {
        let storedAt: Date
        let expiresAt: Date
    }

    private let diskStore: any DiskStoreContract
    private let now: @Sendable () -> Date
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Encoded envelopes, not decoded values: the payload type is only known at
    /// the call site, so caching decoded values would need one heterogeneous box
    /// per type. Holding the bytes keeps this layer type-agnostic and still
    /// removes the file read, which is the expensive part — a value read twice in
    /// one session touches the disk once.
    private var memory: [CacheKey: Data] = [:]
    /// Insertion order, so the layer can stay bounded with a plain FIFO drop.
    /// A cache of a cache does not deserve an LRU.
    private var memoryOrder: [CacheKey] = []
    private let memoryCountLimit: Int

    /// - Parameters:
    ///   - now: injectable clock. Expiry is the one behaviour here that cannot be
    ///     tested without waiting for real time, so it is a dependency.
    ///   - memoryCountLimit: how many encoded envelopes to keep in memory.
    public init(
        diskStore: any DiskStoreContract,
        now: @escaping @Sendable () -> Date = Date.init,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        memoryCountLimit: Int = 64
    ) {
        self.diskStore = diskStore
        self.now = now
        self.encoder = encoder
        self.decoder = decoder
        self.memoryCountLimit = max(0, memoryCountLimit)
    }

    // MARK: - CacheStoreContract

    public func entry<Value: Codable & Sendable>(
        for key: CacheKey,
        as type: Value.Type
    ) async throws -> CacheEntry<Value>? {
        let data: Data
        if let cached = memory[key] {
            data = cached
        } else {
            guard let stored = try await diskStore.data(for: key) else { return nil }
            remember(stored, for: key)
            data = stored
        }

        guard let envelope = try? decoder.decode(Envelope<Value>.self, from: data) else {
            // A miss, not a throw. The stored shape changes whenever a model
            // gains a field, and an app that refused to launch — or a screen that
            // refused to load — because last week's JSON no longer decodes would
            // be a cache turning itself into a bug. Drop it and re-fetch.
            try? await remove(key)
            return nil
        }

        return CacheEntry(
            value: envelope.value,
            storedAt: envelope.storedAt,
            expiresAt: envelope.expiresAt,
            // Evaluated on read rather than stored: a value written before the
            // app was backgrounded for a day must come back expired.
            isExpired: now() >= envelope.expiresAt
        )
    }

    public func store<Value: Codable & Sendable>(
        _ value: Value,
        for key: CacheKey,
        lifetime: TimeInterval
    ) async throws {
        let storedAt = now()
        let envelope = Envelope(
            storedAt: storedAt,
            expiresAt: storedAt.addingTimeInterval(lifetime),
            value: value
        )
        let data = try encoder.encode(envelope)
        try await diskStore.store(data, for: key)
        remember(data, for: key)
    }

    public func remove(_ key: CacheKey) async throws {
        forget(key)
        try await diskStore.remove(key)
    }

    public func removeExpired() async throws {
        let now = now()
        for namespace in try await diskStore.namespaces() {
            for entry in try await diskStore.entries(in: namespace) {
                guard try await isExpired(entry, in: namespace, at: now) else { continue }
                try? await diskStore.remove(fileNamed: entry.fileName, in: namespace)
            }
        }
        // The sweep deletes files whose keys it cannot reconstruct, so the memory
        // layer cannot be invalidated selectively. It is small and rebuilt from
        // disk on demand, so dropping all of it is both correct and cheap.
        memory.removeAll()
        memoryOrder.removeAll()
    }

    /// - Returns: `true` only for a file that is positively an expired envelope.
    ///
    ///   A file that cannot be read, or does not decode as an envelope, is left
    ///   alone. The disk store is shared with other layers — the image cache
    ///   writes raw JPEG bytes through the same `DiskStoreContract` under its own
    ///   namespace — and the sweep cannot tell "corrupt envelope" from "someone
    ///   else's file". Deleting on doubt once wiped every cached avatar at launch.
    ///   A genuinely corrupt envelope is still collected, on the next read of its
    ///   key (see `entry(for:as:)`); and one unreadable file never aborts the
    ///   sweep for every other namespace.
    private func isExpired(_ entry: DiskStoreEntry, in namespace: String, at now: Date) async throws -> Bool {
        guard let data = try? await diskStore.data(fileNamed: entry.fileName, in: namespace),
              let header = try? decoder.decode(EnvelopeHeader.self, from: data) else {
            return false
        }
        return now >= header.expiresAt
    }

    // MARK: - Memory layer

    private func remember(_ data: Data, for key: CacheKey) {
        guard memoryCountLimit > 0 else { return }
        if memory[key] == nil {
            memoryOrder.append(key)
        }
        memory[key] = data
        while memoryOrder.count > memoryCountLimit {
            memory.removeValue(forKey: memoryOrder.removeFirst())
        }
    }

    private func forget(_ key: CacheKey) {
        guard memory.removeValue(forKey: key) != nil else { return }
        memoryOrder.removeAll { $0 == key }
    }
}
