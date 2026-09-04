import Foundation

/// Somewhere log events go.
///
/// The client does not know or care what happens to an event — printing it,
/// keeping it for a screen, dropping it — so it talks to this one-method
/// protocol and the composition root decides. `nonisolated` and synchronous on
/// purpose: a sink must never make the network call wait, so anything slow
/// (disk, UI) belongs behind a `Task` inside the sink.
public protocol APILogSinkContract: Sendable {
    func log(_ event: APILogEvent)
}

/// The default sink: discards everything.
///
/// Exists so `GraphQLClient` has a logger unconditionally and `execute` has no
/// optional to unwrap. Tests and previews that do not care about logging get
/// this without asking.
public struct NoOpAPILogger: APILogSinkContract {
    public init() {}

    public func log(_ event: APILogEvent) {}
}
