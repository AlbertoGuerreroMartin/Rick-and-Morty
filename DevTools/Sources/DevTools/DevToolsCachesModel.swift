//
//  DevToolsCachesModel.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Observation
import Storage

/// What the cache list is showing right now: per-row result and whether a clear is in flight.
@MainActor
@Observable
final class DevToolsCachesModel {

    enum Result: Equatable {
        case cleared
        case failed(String)
    }

    private(set) var results: [String: Result] = [:]
    /// Disables every button while a clear is in flight, so a double tap can't wipe twice.
    private(set) var isClearing = false

    /// Injectable so tests can listen on a centre of their own.
    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func clear(_ cache: DevToolsCache) async {
        if await run(cache) {
            announce([cache.name])
        }
    }

    /// Sequential, not a task group: these hit the same disk store, and one failure doesn't
    /// stop the rest. Announced once at the end so listeners don't reload three times over.
    func clearAll(_ caches: [DevToolsCache]) async {
        var cleared: [String] = []
        for cache in caches where await run(cache) {
            cleared.append(cache.name)
        }
        if !cleared.isEmpty {
            announce(cleared)
        }
    }

    /// - Returns: whether the cache was cleared.
    private func run(_ cache: DevToolsCache) async -> Bool {
        isClearing = true
        defer { isClearing = false }
        do {
            try await cache.clear()
            results[cache.id] = .cleared
            return true
        } catch {
            results[cache.id] = .failed(error.localizedDescription)
            return false
        }
    }

    /// Posts to `Storage`'s notification; doesn't know which screens exist or listen.
    private func announce(_ cacheNames: [String]) {
        CacheClearedNotification.post(cacheNames: cacheNames, center: notificationCenter)
    }
}
