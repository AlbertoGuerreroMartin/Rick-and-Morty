//
//  CodableCacheStore.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation

/// The default ``CacheStoreContract``: JSON envelopes on a ``DiskStoreContract``.
/// An actor: the in-memory layer is mutable state shared by every caller.
public actor CodableCacheStore: CacheStoreContract {

    private struct Envelope<Value: Codable & Sendable>: Codable, Sendable {
        let storedAt: Date
        let expiresAt: Date
        let value: Value
    }

    /// ``Envelope``'s date fields with `value` left undecoded, so the expiry sweep never
    /// materializes a payload it is about to delete.
    private struct EnvelopeHeader: Decodable {
        let storedAt: Date
        let expiresAt: Date
    }

    private let diskStore: any DiskStoreContract
    private let now: @Sendable () -> Date
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger: any CacheLogSinkContract

    /// Encoded envelopes, not decoded values: keeps this layer type-agnostic and still avoids
    /// the file read on a repeat lookup.
    private var memory: [CacheKey: Data] = [:]
    /// Insertion order, for a plain FIFO eviction.
    private var memoryOrder: [CacheKey] = []
    private let memoryCountLimit: Int

    /// - Parameters:
    ///   - now: injectable clock; expiry can't otherwise be tested without waiting on real time.
    ///   - memoryCountLimit: how many encoded envelopes to keep in memory.
    ///   - logger: defaults to a no-op.
    public init(
        diskStore: any DiskStoreContract,
        now: @escaping @Sendable () -> Date = Date.init,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        memoryCountLimit: Int = 64,
        logger: any CacheLogSinkContract = NoOpCacheLogger()
    ) {
        self.diskStore = diskStore
        self.now = now
        self.encoder = encoder
        self.decoder = decoder
        self.memoryCountLimit = max(0, memoryCountLimit)
        self.logger = logger
    }

    // MARK: - CacheStoreContract

    public func entry<Value: Codable & Sendable>(
        for key: CacheKey,
        as type: Value.Type
    ) async throws -> CacheEntry<Value>? {
        let data: Data
        // Captured here, not derived later: `remember` puts a disk read into memory before decode.
        let layer: CacheLogEvent.Layer
        if let cached = memory[key] {
            data = cached
            layer = .memory
        } else {
            guard let stored = try await diskStore.data(for: key) else {
                logger.log(CacheLogEvent(key: key, outcome: .miss))
                return nil
            }
            remember(stored, for: key)
            data = stored
            layer = .disk
        }

        guard let envelope = try? decoder.decode(Envelope<Value>.self, from: data) else {
            // A miss, not a throw: an out-of-date shape must re-fetch rather than crash the app.
            try? await remove(key)
            logger.log(CacheLogEvent(key: key, outcome: .miss))
            return nil
        }

        // Evaluated on read, not stored, so backgrounded time counts toward expiry.
        let isExpired = now() >= envelope.expiresAt
        logger.log(CacheLogEvent(key: key, outcome: .hit(layer: layer, isExpired: isExpired)))

        return CacheEntry(
            value: envelope.value,
            storedAt: envelope.storedAt,
            expiresAt: envelope.expiresAt,
            isExpired: isExpired
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

    public func removeAll(in namespace: String) async throws {
        // Keys are known here, unlike in the sweep below, so memory can be trimmed to this namespace.
        for key in memory.keys where key.namespace == namespace {
            forget(key)
        }
        try await diskStore.removeAll(in: namespace)
    }

    public func removeExpired() async throws {
        let now = now()
        for namespace in try await diskStore.namespaces() {
            for entry in try await diskStore.entries(in: namespace) {
                guard try await isExpired(entry, in: namespace, at: now) else { continue }
                try? await diskStore.remove(fileNamed: entry.fileName, in: namespace)
            }
        }
        // Keys can't be reconstructed from deleted files, so memory is dropped wholesale
        // rather than invalidated selectively.
        memory.removeAll()
        memoryOrder.removeAll()
    }

    /// - Returns: `true` only for a file that is positively an expired envelope. An unreadable or
    ///   non-envelope file is left alone: the disk store is shared with other layers (e.g. the
    ///   image cache) writing their own files under it, so deleting on doubt is unsafe.
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
