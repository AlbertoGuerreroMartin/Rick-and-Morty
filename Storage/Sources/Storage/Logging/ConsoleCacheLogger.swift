//
//  ConsoleCacheLogger.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import os

/// Writes every cache event to the unified logging system, which Xcode shows in its console.
/// Category is "Cache", separate from Networking's "API": cache reads happen by the hundred and
/// would otherwise bury the handful of requests that actually left the device.
public struct ConsoleCacheLogger: CacheLogSinkContract {
    private let formatter: CacheLogFormatter
    private let logger: Logger

    /// - Parameters:
    ///   - subsystem: typically the app's bundle identifier, for filtering in Console.app.
    ///   - category: shown as a column in Xcode.
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

/// Turns a cache event into one console line: `namespace › identifier`, printed verbatim (not
/// hashed) since the on-disk SHA-256 name can't be read back to match a log line to its query.
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
            // Freshness before layer: "is this entry usable" is the reader's first question.
            return "HIT (\(isExpired ? "expired" : "fresh"), \(layer.rawValue))"
        case .miss:
            return "MISS"
        }
    }
}
