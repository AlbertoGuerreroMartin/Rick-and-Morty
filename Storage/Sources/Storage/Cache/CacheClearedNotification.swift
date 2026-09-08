//
//  CacheClearedNotification.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// Announces a cache was wiped from outside the normal data flow (e.g. a developer-tools screen),
/// so any screen showing cached data can reload without either side naming the other. Screens
/// should reload on any post rather than match names — a reload against an uncleared cache
/// costs no request anyway. Posted on the main actor so SwiftUI's `onReceive` can drive state.
public enum CacheClearedNotification {
    public static let name = Notification.Name("Storage.cacheDidClear")
    public static let cacheNamesKey = "cacheNames"

    @MainActor
    public static func post(cacheNames: [String], center: NotificationCenter = .default) {
        center.post(name: name, object: nil, userInfo: [cacheNamesKey: cacheNames])
    }

    public static func cacheNames(from notification: Notification) -> [String] {
        notification.userInfo?[cacheNamesKey] as? [String] ?? []
    }
}

public extension Notification.Name {
    /// See ``CacheClearedNotification``.
    static let cacheDidClear = CacheClearedNotification.name
}
