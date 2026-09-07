//
//  CacheLogStore.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Synchronization

/// Keeps every cache event and fans each one out to other sinks.
///
/// This is the seam for anything outside `Storage` that wants to see the cache
/// traffic. A developer-tools screen reads `events` for the history and then
/// listens to `stream()` for what happens next; the console logger is just
/// another sink registered through `add(_:)`. ``CodableCacheStore`` only ever
/// sees a sink, so this store is one possible wiring, not a requirement.
///
/// The same shape as `APILogStore` in Networking, deliberately duplicated: the
/// two packages cannot share a type without one importing the other, and this
/// is thirty lines of plumbing rather than a design worth inverting a
/// dependency for.
///
/// A class under a `Mutex` rather than an actor, for the same reason as the API
/// store: `log(_:)` has to be synchronous so a cache read never awaits it, and
/// an actor would force that call through a detached `Task` — which is
/// unordered, so two reads of the same key could land out of order. The critical
/// section is an array append and a handful of yields.
public final class CacheLogStore: CacheLogSinkContract, Sendable {
    private struct State {
        var events: [CacheLogEvent] = []
        var sinks: [any CacheLogSinkContract] = []
        var continuations: [UUID: AsyncStream<CacheLogEvent>.Continuation] = [:]
    }

    private let state: Mutex<State>
    private let capacity: Int

    /// - Parameters:
    ///   - sinks: receive every event from the first one.
    ///   - capacity: how many events the history keeps; the oldest are dropped
    ///     past it. Every image the loader draws is a cache read, so a scroll
    ///     produces events far faster than anyone reads them and an unbounded
    ///     history would grow for the life of the process.
    public init(sinks: [any CacheLogSinkContract] = [], capacity: Int = 500) {
        state = Mutex(State(sinks: sinks))
        self.capacity = max(0, capacity)
    }

    /// Everything logged so far, oldest first.
    public var events: [CacheLogEvent] {
        state.withLock { $0.events }
    }

    /// Registers a sink that receives every event from now on.
    public func add(_ sink: any CacheLogSinkContract) {
        state.withLock { $0.sinks.append(sink) }
    }

    /// Live events from the moment of subscription. Finishes when the consumer
    /// stops iterating; each call gets its own independent stream.
    public func stream() -> AsyncStream<CacheLogEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: CacheLogEvent.self)
        let key = UUID()
        state.withLock { $0.continuations[key] = continuation }
        continuation.onTermination = { [weak self] _ in
            self?.state.withLock { $0.continuations[key] = nil }
        }
        return stream
    }

    /// Drops the history. Registered sinks and live streams are unaffected.
    public func removeAll() {
        state.withLock { $0.events.removeAll() }
    }

    public func log(_ event: CacheLogEvent) {
        // Sinks run outside the lock: one of them could log back into this
        // store (a bug, but not one that should deadlock).
        let (sinks, continuations) = state.withLock { state in
            state.events.append(event)
            // Only the history is capped: sinks and live streams have already
            // been handed the event.
            if state.events.count > capacity {
                state.events.removeFirst(state.events.count - capacity)
            }
            return (state.sinks, Array(state.continuations.values))
        }
        for sink in sinks {
            sink.log(event)
        }
        for continuation in continuations {
            continuation.yield(event)
        }
    }
}
