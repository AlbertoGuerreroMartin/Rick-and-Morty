//
//  DevToolsCachesModel.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Observation
import Storage

/// What the cache list is showing right now.
///
/// The one piece of this package with behaviour worth testing on its own: what
/// a row shows after it is tapped, and that "Clear all" reaches every cache
/// exactly once. Everything else on ``DevToolsScreen`` is layout, and putting
/// this in a type rather than in `@State` is what lets a test drive it without
/// hunting for a button in a UIKit hierarchy SwiftUI makes no promises about.
@MainActor
@Observable
final class DevToolsCachesModel {

    enum Result: Equatable {
        case cleared
        case failed(String)
    }

    /// Cache name to what happened last time it was cleared.
    private(set) var results: [String: Result] = [:]
    /// Disables every button while one clear is in flight, so a double tap
    /// cannot run two wipes of the same directory at once.
    private(set) var isClearing = false

    /// Where a successful clear is announced — see `CacheClearedNotification`.
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

    /// Sequentially, not in a task group: these are disk operations on the same
    /// store, and running them concurrently would only make a failure harder to
    /// attribute to a cache. One failing cache does not stop the rest.
    ///
    /// Announced once at the end rather than once per cache: every screen that
    /// listens reloads on each post, and three posts in a row would be three
    /// reloads racing each other — and spending three requests against the
    /// rate limit for one tap.
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
            // Shown rather than swallowed: a cache that refuses to clear is
            // exactly the kind of thing this screen exists to surface.
            results[cache.id] = .failed(error.localizedDescription)
            return false
        }
    }

    /// Tells whoever is showing cached data to load it again. This is the
    /// entire extent of what the tool knows about the app's screens: nothing.
    /// It does not know which screens exist, which are alive, or which cache
    /// each one reads — it says "a cache is gone" into `Storage`'s notification
    /// and the screens take it from there.
    private func announce(_ cacheNames: [String]) {
        CacheClearedNotification.post(cacheNames: cacheNames, center: notificationCenter)
    }
}
