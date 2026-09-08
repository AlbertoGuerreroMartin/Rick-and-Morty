//
//  CacheLogSinkContract.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// Somewhere cache events go; the store doesn't know or care what a sink does with one. Sync,
/// since a sink must never make a cache read wait — anything slow belongs behind a `Task` inside it.
///
/// A second protocol rather than reusing `APILogSinkContract`: Storage can't import Networking
/// without inverting the dependency.
public protocol CacheLogSinkContract: Sendable {
    func log(_ event: CacheLogEvent)
}

/// Discards everything, so ``CodableCacheStore`` has a logger unconditionally with no optional
/// to unwrap.
public struct NoOpCacheLogger: CacheLogSinkContract {
    public init() {}

    public func log(_ event: CacheLogEvent) {}
}
