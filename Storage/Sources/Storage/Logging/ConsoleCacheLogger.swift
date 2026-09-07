//
//  ConsoleCacheLogger.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import os

/// Writes every cache event to the unified logging system, which Xcode shows in
/// its console.
///
/// The category is "Cache", a different one from Networking's "API", and that
/// separation is the point rather than a detail. A cache read happens for every
/// row and every avatar, so interleaving them with the network log would bury
/// the handful of requests that actually left the device under hundreds of
/// hits. Two categories mean the Xcode console filter picks one or the other,
/// and Console.app shows them as separate columns.
///
/// The text is built by ``CacheLogFormatter`` so the format is testable without
/// capturing output; this type only decides *where* the text goes. Unlike a
/// network log, one event is one line — there is nothing to unpack — but
/// `os.Logger` is still the right sink for the filtering above.
public struct ConsoleCacheLogger: CacheLogSinkContract {
    private let formatter: CacheLogFormatter
    private let logger: Logger

    /// - Parameters:
    ///   - subsystem: the unified-logging subsystem, typically the app's bundle
    ///     identifier, so the entries can be filtered by app in Console.app.
    ///   - category: the unified-logging category, shown as a column in Xcode.
    public init(
        subsystem: String = "Storage",
        category: String = "Cache",
        timeZone: TimeZone = .current
    ) {
        formatter = CacheLogFormatter(timeZone: timeZone)
        logger = Logger(subsystem: subsystem, category: category)
    }

    public func log(_ event: CacheLogEvent) {
        logger.debug("\(formatter.string(for: event), privacy: .public)")
    }
}

/// Turns a cache event into the one line the console shows.
///
/// ```
/// 🗂️ 14:20:37.360 > [Cache] HIT (fresh, disk) characters › characters|<hash>|{"page":1}
/// 🗂️ 14:20:37.360 > [Cache] HIT (expired, memory) episodes › episodes|<hash>|{"page":2}
/// 🗂️ 14:20:37.360 > [Cache] MISS images › https://rickandmortyapi.com/api/character/avatar/1.jpeg
/// ```
///
/// One line per event, because these arrive by the hundred: a multi-line entry
/// per avatar would make the console unreadable exactly when it matters. The key
/// is printed verbatim, `namespace › identifier`, and not hashed — the on-disk
/// name is a SHA-256 that cannot be read back, so the identifier is the only
/// thing that lets a reader match a log line to the query that produced it.
public struct CacheLogFormatter: Sendable {
    private let timeFormatter: DateFormatter

    public init(timeZone: TimeZone = .current) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm:ss.SSS"
        timeFormatter = formatter
    }

    public func string(for event: CacheLogEvent) -> String {
        let time = timeFormatter.string(from: event.timestamp)
        let key = "\(event.key.namespace) › \(event.key.identifier)"
        return "🗂️ \(time) > [Cache] \(outcome(event.outcome)) \(key)"
    }

    private func outcome(_ outcome: CacheLogEvent.Outcome) -> String {
        switch outcome {
        case .hit(let layer, let isExpired):
            // Freshness before layer: "is this entry usable" is the question a
            // reader has first, and the layer only explains how fast it was.
            return "HIT (\(isExpired ? "expired" : "fresh"), \(layer.rawValue))"
        case .miss:
            return "MISS"
        }
    }
}
