//
//  RequestInspectorEntry.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Storage

/// One row of the inspector: an API call, an image download, or a cache read,
/// flattened into the same shape.
///
/// Three sources with three different event types become one list here rather
/// than three parallel lists, because the question the screen answers is
/// chronological — "what happened when this screen loaded" — and an answer split
/// across three tabs cannot show that a cache miss is what caused the request
/// underneath it.
///
/// The texts are pre-rendered by the packages' own formatters rather than built
/// here. The console and the inspector then cannot disagree about what a request
/// looked like, which they would the moment one of them grew a second formatter.
struct RequestInspectorEntry: Identifiable, Equatable, Sendable {

    enum Kind: String, Sendable {
        case api
        case image
        case cache
    }

    enum Status: Equatable, Sendable {
        /// A request that has left but whose response has not arrived. Also what
        /// a request whose response never arrives stays as.
        case pending
        case success(Int)
        case failure(Int)
        case transportError
        case cacheHit(isExpired: Bool, layer: String)
        case cacheMiss
    }

    /// Shared with the network records, which is how a `.response` finds the
    /// `.request` it belongs to.
    let id: UUID
    let timestamp: Date
    let kind: Kind
    /// `[METHOD] url` for traffic, `namespace › identifier` for a cache read.
    let title: String
    let status: Status
    /// Round-trip time, once a response has arrived.
    let duration: TimeInterval?
    let requestText: String
    /// `nil` until the response lands. A cache read has none — there is one
    /// line and it is the whole event, so it goes in `requestText`.
    let responseText: String?
}

extension RequestInspectorEntry {

    /// Everything the detail screen would show, in one string, for the search
    /// field. The whole text rather than the title alone: the reason to search
    /// a network log is almost never the URL — every GraphQL call has the same
    /// one — but a character's name in a response body, a variable in a query,
    /// or a status code.
    var searchableText: String {
        [title, requestText, responseText].compactMap { $0 }.joined(separator: "\n")
    }

    /// A request that has just left, with nothing filled in below the fold yet.
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

    /// The same entry with its response filled in.
    func completed(with response: APIResponseRecord, formatter: APILogFormatter) -> RequestInspectorEntry {
        RequestInspectorEntry(
            id: id,
            // The request's timestamp is kept on purpose: the list is ordered by
            // when a call *started*, so an entry does not jump to the top of the
            // list the moment a slow response lands.
            timestamp: timestamp,
            kind: kind,
            title: title,
            status: Status(response.outcome),
            duration: response.duration,
            requestText: requestText,
            responseText: formatter.string(for: response)
        )
    }

    /// A response whose request is not in the list.
    ///
    /// It happens for real: the store's cap drops the oldest events, so an
    /// inspector opened mid-scroll sees responses to requests that fell off the
    /// end. Showing them as their own row is better than dropping them — the
    /// response carries the URL and the status, which is most of what a reader
    /// wanted from the pair.
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

    /// What the trailing edge of a row shows. Short enough to sit beside a URL
    /// without pushing it off screen, which is why an expired hit is
    /// "HIT (expired)" rather than naming its layer too — the layer is in the
    /// detail view.
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
