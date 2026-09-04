import Foundation

/// One HTTP request as it left the client.
///
/// Plain values on purpose: no `URLRequest`, no `URLResponse`. The records are
/// meant to be displayed by code that knows nothing about `URLSession` — the
/// console today, a developer-tools screen later — so they carry only what such
/// a consumer can render. `id` is shared with the matching `APIResponseRecord`,
/// which is how a consumer pairs the two halves of one call.
public struct APIRequestRecord: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let method: String
    public let url: URL
    /// Header name to value, unsorted. Formatters sort for stable output.
    public let headers: [String: String]
    public let body: Data?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        method: String,
        url: URL,
        headers: [String: String],
        body: Data?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

/// What came back for an `APIRequestRecord`, or why nothing did.
public struct APIResponseRecord: Sendable, Identifiable, Equatable {
    /// How the call ended, as far as the transport is concerned.
    ///
    /// This is deliberately *not* the client's notion of failure: a GraphQL
    /// error arrives as a `200 OK` with an `errors` array, and a body that does
    /// not decode is still a body the server sent. Both are `.success` here,
    /// because the log's job is to show what crossed the wire.
    public enum Outcome: Sendable, Equatable {
        /// A 2xx status.
        case success(statusCode: Int)
        /// The server answered with a non-2xx status.
        case failure(statusCode: Int)
        /// The request never produced a response (offline, DNS, timeout...).
        case transportError(description: String)
    }

    /// Same value as the request's `id`.
    public let id: UUID
    public let timestamp: Date
    public let method: String
    public let url: URL
    public let outcome: Outcome
    public let headers: [String: String]
    public let body: Data?
    /// Wall-clock time between the request leaving and this record.
    public let duration: TimeInterval

    public init(
        id: UUID,
        timestamp: Date = Date(),
        method: String,
        url: URL,
        outcome: Outcome,
        headers: [String: String],
        body: Data?,
        duration: TimeInterval
    ) {
        self.id = id
        self.timestamp = timestamp
        self.method = method
        self.url = url
        self.outcome = outcome
        self.headers = headers
        self.body = body
        self.duration = duration
    }

    /// The status code when there was a response, `nil` for a transport error.
    public var statusCode: Int? {
        switch outcome {
        case .success(let code), .failure(let code):
            return code
        case .transportError:
            return nil
        }
    }

    /// Size of the body in bytes; zero when there was none.
    public var length: Int {
        body?.count ?? 0
    }
}

/// One thing the client did. A call produces exactly two: a `.request` when it
/// is sent and a `.response` when it ends, in that order, sharing an `id`.
public enum APILogEvent: Sendable, Equatable {
    case request(APIRequestRecord)
    case response(APIResponseRecord)

    public var id: UUID {
        switch self {
        case .request(let record):
            return record.id
        case .response(let record):
            return record.id
        }
    }
}
