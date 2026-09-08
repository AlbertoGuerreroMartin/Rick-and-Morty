//
//  CacheLogEvent.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// One read of the cache. Only reads are logged — a write is never a surprise, but a miss on a
/// key the caller expected to have found is what needs explaining. Plain values, like
/// ``APIRequestRecord`` in Networking, so a consumer needs no knowledge of envelopes or files.
public struct CacheLogEvent: Sendable, Equatable, Identifiable {

    /// Which layer answered a hit. A `disk` answer right after a `memory` one for the same key
    /// means the memory layer is evicting more than it should.
    public enum Layer: String, Sendable {
        case memory
        case disk
    }

    /// An expired hit is a hit, not a miss: the entry was there, and whether stale data is
    /// acceptable is the repository's call (see ``CacheEntry``).
    public enum Outcome: Sendable, Equatable {
        case hit(layer: Layer, isExpired: Bool)
        case miss
    }

    public let id: UUID
    public let timestamp: Date
    public let key: CacheKey
    public let outcome: Outcome

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        key: CacheKey,
        outcome: Outcome
    ) {
        self.id = id
        self.timestamp = timestamp
        self.key = key
        self.outcome = outcome
    }
}
