import Foundation
import Synchronization

/// Keeps every event and fans each one out to other sinks.
///
/// This is the seam for anything outside `Networking` that wants to see the
/// traffic. A developer-tools screen reads `events` for the history and then
/// listens to `stream()` for what happens next; the console logger is just
/// another sink registered through `add(_:)`. `GraphQLClient` only ever sees a
/// sink, so the store is one possible wiring, not a requirement.
///
/// A class under a `Mutex` rather than an actor, deliberately. `log(_:)` has to
/// be synchronous so the client never awaits it, and an actor would force that
/// call through a detached `Task` — which is unordered, so a call's `.response`
/// could land in the history before its `.request`. The critical section is an
/// array append and a handful of yields, far too short for the mutex to matter.
public final class APILogStore: APILogSinkContract, Sendable {
    private struct State {
        var events: [APILogEvent] = []
        var sinks: [any APILogSinkContract] = []
        var continuations: [UUID: AsyncStream<APILogEvent>.Continuation] = [:]
    }

    private let state: Mutex<State>

    /// - Parameter sinks: receive every event from the first one.
    public init(sinks: [any APILogSinkContract] = []) {
        state = Mutex(State(sinks: sinks))
    }

    /// Everything logged so far, oldest first.
    public var events: [APILogEvent] {
        state.withLock { $0.events }
    }

    /// Registers a sink that receives every event from now on.
    public func add(_ sink: any APILogSinkContract) {
        state.withLock { $0.sinks.append(sink) }
    }

    /// Live events from the moment of subscription. Finishes when the consumer
    /// stops iterating; each call gets its own independent stream.
    public func stream() -> AsyncStream<APILogEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: APILogEvent.self)
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

    public func log(_ event: APILogEvent) {
        // Sinks run outside the lock: one of them could log back into this
        // store (a bug, but not one that should deadlock).
        let (sinks, continuations) = state.withLock { state in
            state.events.append(event)
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
