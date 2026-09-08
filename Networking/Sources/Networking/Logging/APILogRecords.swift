import Foundation

/// What kind of traffic a record describes. Records are identical for both — a method, URL,
/// headers, bytes — so image loading reuses them; the console and inspector use kind to filter.
public enum APILogKind: String, Sendable, Equatable {
    case api
    case image
}

/// One HTTP request as it left the client, in plain values (no `URLRequest`) so a console or
/// debug screen can render it without knowing `URLSession`. `id` pairs it with its
/// `APIResponseRecord`.
public struct APIRequestRecord: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    /// Defaults to `.api` so existing call sites keep compiling.
    public let kind: APILogKind
    public let method: String
    public let url: URL
    /// Unsorted; formatters sort for stable output.
    public let headers: [String: String]
    public let body: Data?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: APILogKind = .api,
        method: String,
        url: URL,
        headers: [String: String],
        body: Data?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

/// What came back for an `APIRequestRecord`, or why nothing did.
public struct APIResponseRecord: Sendable, Identifiable, Equatable {
    /// How the call ended, transport-wise — not the client's notion of failure: a GraphQL error
    /// is still a `200 OK` here, since the log shows what crossed the wire.
    public enum Outcome: Sendable, Equatable {
        case success(statusCode: Int)
        case failure(statusCode: Int)
        /// The request never produced a response (offline, DNS, timeout...).
        case transportError(description: String)
    }

    /// Same value as the request's `id`.
    public let id: UUID
    public let timestamp: Date
    /// Matches the request's kind; defaults to `.api` for the same reason.
    public let kind: APILogKind
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
        kind: APILogKind = .api,
        method: String,
        url: URL,
        outcome: Outcome,
        headers: [String: String],
        body: Data?,
        duration: TimeInterval
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
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

/// One thing the client did: `.request` when sent, `.response` when it ends, sharing an `id`.
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
