//
//  CacheLogStore.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Synchronization

/// Keeps every cache event and fans each one out to registered sinks — the seam for anything
/// outside `Storage` that wants to see cache traffic. Same shape as `APILogStore` in Networking,
/// deliberately duplicated since the two packages cannot share a type without a dependency.
///
/// A class under a `Mutex`, not an actor: `log(_:)` must stay synchronous, since an actor would
/// force it through a detached `Task`, letting two reads of the same key land out of order.
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
    ///   - capacity: how many events the history keeps; oldest are dropped past it, since a
    ///     scroll produces events far faster than anyone reads them.
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
        // Sinks run outside the lock: one could log back into this store without deadlocking.
        let (sinks, continuations) = state.withLock { state in
            state.events.append(event)
            // Only the history is capped; sinks/streams already saw the event.
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
