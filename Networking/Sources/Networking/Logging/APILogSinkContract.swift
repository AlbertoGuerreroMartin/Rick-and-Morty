import Foundation

/// Somewhere log events go; the client doesn't know or care what a sink does with one. Sync,
/// since a sink must never make the network call wait — anything slow belongs behind a `Task`.
public protocol APILogSinkContract: Sendable {
    func log(_ event: APILogEvent)
}

/// Discards everything, so `GraphQLClient` has a logger unconditionally with no optional to unwrap.
public struct NoOpAPILogger: APILogSinkContract {
    public init() {}

    public func log(_ event: APILogEvent) {}
}
