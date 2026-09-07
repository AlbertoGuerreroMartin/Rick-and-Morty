//
//  CacheLogEvent.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// One read of the cache, as seen by someone trying to explain why a screen
/// went to the network.
///
/// A read is the only event worth logging. A write is never a surprise — it is
/// the direct consequence of a fetch that has already been logged as a request
/// — while a miss on a key the caller was sure it had stored is exactly the
/// thing that needs explaining, and the answer is always in the key.
///
/// Plain values, like ``APIRequestRecord`` in Networking: whoever renders this
/// knows nothing about envelopes, files or expiry dates, so the event carries
/// only what such a consumer can show.
public struct CacheLogEvent: Sendable, Equatable, Identifiable {

    /// Which layer answered a hit.
    ///
    /// The distinction is the whole reason the memory layer exists: a read that
    /// says `disk` when the previous read of the same key said `memory` is a
    /// memory layer that is evicting more than it should.
    public enum Layer: String, Sendable {
        case memory
        case disk
    }

    /// What the read found.
    ///
    /// An expired hit is a hit, not a miss: the entry was there and the store
    /// handed it back, and whether stale data is acceptable is the repository's
    /// call (see ``CacheEntry``). Logging it as a miss would hide the one case
    /// where the cache did its job and the caller chose to refetch anyway.
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
