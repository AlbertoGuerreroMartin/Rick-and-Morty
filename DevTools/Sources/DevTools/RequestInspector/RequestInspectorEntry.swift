//
//  RequestInspectorEntry.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Storage

/// One row of the inspector: an API call, an image download, or a cache read, flattened
/// into the same shape so the list can be one chronological feed.
struct RequestInspectorEntry: Identifiable, Equatable, Sendable {

    enum Kind: String, Sendable {
        case api
        case image
        case cache
    }

    enum Status: Equatable, Sendable {
        /// Also what a request whose response never arrives stays as.
        case pending
        case success(Int)
        case failure(Int)
        case transportError
        case cacheHit(isExpired: Bool, layer: String)
        case cacheMiss
    }

    /// Shared with the network record, so a `.response` finds its `.request`.
    let id: UUID
    let timestamp: Date
    let kind: Kind
    /// `[METHOD] url` for traffic, `namespace › identifier` for a cache read.
    let title: String
    let status: Status
    let duration: TimeInterval?
    let requestText: String
    /// `nil` until the response lands. A cache read has none: it's one line, in `requestText`.
    let responseText: String?
}

extension RequestInspectorEntry {

    /// Full text for the search field: a body match (a name, a variable) is more useful
    /// than the URL alone, since every GraphQL call shares one.
    var searchableText: String {
        [title, requestText, responseText].compactMap { $0 }.joined(separator: "\n")
    }

    init(request: APIRequestRecord, formatter: APILogFormatter) {
        self.init(
            id: request.id,
            timestamp: request.timestamp,
            kind: request.kind == .image ? .image : .api,
            title: "[\(request.method)] \(request.url.absoluteString)",
            status: .pending,
            duration: nil,
            requestText: formatter.string(for: request),
            responseText: nil
        )
    }

    func completed(with response: APIResponseRecord, formatter: APILogFormatter) -> RequestInspectorEntry {
        RequestInspectorEntry(
            id: id,
            // Kept, not replaced: the list orders by when a call started, not when it finished.
            timestamp: timestamp,
            kind: kind,
            title: title,
            status: Status(response.outcome),
            duration: response.duration,
            requestText: requestText,
            responseText: formatter.string(for: response)
        )
    }

    /// A response whose request fell off the log's capped storage before it arrived.
    init(orphanResponse response: APIResponseRecord, formatter: APILogFormatter) {
        self.init(
            id: response.id,
            timestamp: response.timestamp,
            kind: response.kind == .image ? .image : .api,
            title: "[\(response.method)] \(response.url.absoluteString)",
            status: Status(response.outcome),
            duration: response.duration,
            requestText: "<the request for this response is no longer in the log>",
            responseText: formatter.string(for: response)
        )
    }

    init(cache event: CacheLogEvent, formatter: CacheLogFormatter) {
        self.init(
            id: event.id,
            timestamp: event.timestamp,
            kind: .cache,
            title: "\(event.key.namespace) › \(event.key.identifier)",
            status: Status(event.outcome),
            duration: nil,
            requestText: formatter.string(for: event),
            responseText: nil
        )
    }
}

extension RequestInspectorEntry.Status {

    init(_ outcome: APIResponseRecord.Outcome) {
        switch outcome {
        case .success(let statusCode):
            self = .success(statusCode)
        case .failure(let statusCode):
            self = .failure(statusCode)
        case .transportError:
            self = .transportError
        }
    }

    init(_ outcome: CacheLogEvent.Outcome) {
        switch outcome {
        case .hit(let layer, let isExpired):
            self = .cacheHit(isExpired: isExpired, layer: layer.rawValue)
        case .miss:
            self = .cacheMiss
        }
    }

    /// Trailing-edge label; kept short to fit beside a URL, so an expired hit omits its layer.
    var text: String {
        switch self {
        case .pending:
            return "PENDING"
        case .success(let statusCode), .failure(let statusCode):
            return "\(statusCode)"
        case .transportError:
            return "ERROR"
        case .cacheHit(let isExpired, _):
            return isExpired ? "HIT (expired)" : "HIT"
        case .cacheMiss:
            return "MISS"
        }
    }
}
