//
//  CacheClearedNotificationTests.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Synchronization
import Testing
@testable import Storage

/// The notification is the whole contract between a tool that clears caches and
/// the screens that show them, so the name and the payload are pinned down.
@Suite("CacheClearedNotification")
@MainActor
struct CacheClearedNotificationTests {

    @Test("a post carries the cleared cache names to every observer")
    func postDeliversTheNames() {
        let center = NotificationCenter()
        let received = Mutex<[[String]]>([])
        let token = center.addObserver(forName: .cacheDidClear, object: nil, queue: nil) { notification in
            received.withLock { $0.append(CacheClearedNotification.cacheNames(from: notification)) }
        }
        defer { center.removeObserver(token) }

        CacheClearedNotification.post(cacheNames: ["Images", "Characters"], center: center)

        #expect(received.withLock { $0 } == [["Images", "Characters"]])
    }

    @Test("a notification without names reads as no names rather than trapping")
    func missingNamesReadAsEmpty() {
        #expect(CacheClearedNotification.cacheNames(from: Notification(name: .cacheDidClear)) == [])
    }
}
