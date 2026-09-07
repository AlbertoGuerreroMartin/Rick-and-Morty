//
//  CacheLogSinkContract.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// Somewhere cache events go.
///
/// The store does not know or care what happens to an event — printing it,
/// keeping it for a screen, dropping it — so it talks to this one-method
/// protocol and the composition root decides. `nonisolated` and synchronous on
/// purpose: a sink must never make a cache read wait, so anything slow (disk,
/// UI) belongs behind a `Task` inside the sink.
///
/// Deliberately a second protocol rather than a reuse of `APILogSinkContract`:
/// Storage cannot import Networking without inverting the dependency — the
/// features depend on both, and Networking has no business knowing about
/// caches. The duplication is a handful of lines and buys each package a log
/// that stands on its own.
public protocol CacheLogSinkContract: Sendable {
    func log(_ event: CacheLogEvent)
}

/// The default sink: discards everything.
///
/// Exists so ``CodableCacheStore`` has a logger unconditionally and its read
/// path has no optional to unwrap. Tests and previews that do not care about
/// logging get this without asking.
public struct NoOpCacheLogger: CacheLogSinkContract {
    public init() {}

    public func log(_ event: CacheLogEvent) {}
}
