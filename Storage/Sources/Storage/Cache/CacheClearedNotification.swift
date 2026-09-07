//
//  CacheClearedNotification.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// Announces that a cache was wiped from *outside* the normal data flow.
///
/// A repository that purges its own cache knows to refetch. A developer-tools
/// screen that wipes a namespace behind every screen's back does not know
/// which screens are alive — and must not: it is a debug tool that should stay
/// ignorant of the features. So the tool posts this, and any screen showing
/// cached data listens and reloads. Neither side names the other; the one thing
/// they share is this notification, which lives here because "a cache was
/// cleared" is Storage's vocabulary rather than the tool's or a feature's.
///
/// The names of the caches cleared travel in `userInfo` for whoever wants to
/// log them. Screens are expected to reload on *any* post rather than match
/// names: the names are whatever the app called its caches, and matching them
/// would tie a screen to a string it never defined. A reload against a cache
/// that was not cleared is answered from that cache, so it costs no request.
///
/// Posted on the main actor, so SwiftUI's `onReceive` can drive state directly.
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
