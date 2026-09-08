//
//  DevToolsViewTests.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Storage
import Synchronization
import SwiftUI
import Testing
import UIKit
@testable import DevTools

@Suite("DevTools views")
@MainActor
struct DevToolsViewTests {

    @Test("the screen draws with caches and with none")
    func screenDraws() async {
        await render(DevToolsScreen(caches: [DevToolsCache(name: "Characters") {},
                                             DevToolsCache(name: "Episodes") {}],
                                    apiLog: APILogStore(),
                                    cacheLog: CacheLogStore()))
        await render(DevToolsScreen(caches: [], apiLog: APILogStore(), cacheLog: CacheLogStore()))
    }

    @Test("clearing every cache runs each of them once and marks them cleared")
    func clearAllRunsEveryCache() async {
        let counts = Mutex([String: Int]())
        let caches = ["Images", "Characters", "Episodes"].map { name in
            DevToolsCache(name: name) { counts.withLock { $0[name, default: 0] += 1 } }
        }
        let center = NotificationCenter()
        let announced = observeClears(on: center)
        let model = DevToolsCachesModel(notificationCenter: center)

        await render(DevToolsScreen(caches: caches, apiLog: APILogStore(), cacheLog: CacheLogStore()))
        await model.clearAll(caches)

        #expect(counts.withLock { $0 } == ["Images": 1, "Characters": 1, "Episodes": 1])
        #expect(model.results == ["Images": .cleared,
                                  "Characters": .cleared,
                                  "Episodes": .cleared])
        #expect(model.isClearing == false)
        #expect(announced.names() == [["Images", "Characters", "Episodes"]])
    }

    @Test("clearing one cache announces that cache by name")
    func clearAnnouncesTheCache() async {
        let center = NotificationCenter()
        let announced = observeClears(on: center)
        let model = DevToolsCachesModel(notificationCenter: center)

        await model.clear(DevToolsCache(name: "Images") {})

        #expect(announced.names() == [["Images"]])
    }

    @Test("a cache that fails shows its error and does not stop the others")
    func failureIsShownAndDoesNotStopTheRest() async {
        struct Failure: LocalizedError {
            var errorDescription: String? { "disk is full" }
        }
        let cleared = Mutex(false)
        let caches = [
            DevToolsCache(name: "Images") { throw Failure() },
            DevToolsCache(name: "Characters") { cleared.withLock { $0 = true } }
        ]
        let center = NotificationCenter()
        let announced = observeClears(on: center)
        let model = DevToolsCachesModel(notificationCenter: center)

        await model.clearAll(caches)

        #expect(model.results["Images"] == .failed("disk is full"))
        #expect(model.results["Characters"] == .cleared)
        #expect(cleared.withLock { $0 })
        #expect(announced.names() == [["Characters"]])
    }

    @Test("a clear that fails everywhere announces nothing")
    func failedClearAnnouncesNothing() async {
        struct Failure: Error {}
        let center = NotificationCenter()
        let announced = observeClears(on: center)
        let model = DevToolsCachesModel(notificationCenter: center)

        await model.clearAll([DevToolsCache(name: "Images") { throw Failure() }])

        #expect(announced.names().isEmpty)
    }

    @Test("the screen draws both cleared and failed rows")
    func screenDrawsResults() async {
        struct Failure: LocalizedError {
            var errorDescription: String? { "disk is full" }
        }
        let caches = [
            DevToolsCache(name: "Images") {},
            DevToolsCache(name: "Characters") { throw Failure() }
        ]
        let screen = DevToolsScreen(caches: caches, apiLog: APILogStore(), cacheLog: CacheLogStore())

        await render(screen)
        for cache in caches {
            _ = try? await cache.clear()
        }
        await render(screen)
    }

    @Test("shaking the window posts the notification the modifier listens for")
    func shakePostsTheNotification() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let received = Mutex(0)
        let token = NotificationCenter.default.addObserver(
            forName: .devToolsDeviceDidShake, object: nil, queue: nil
        ) { _ in received.withLock { $0 += 1 } }
        defer { NotificationCenter.default.removeObserver(token) }

        window.motionEnded(.motionShake, with: nil)
        // A non-shake motion must not post.
        window.motionEnded(UIEvent.EventSubtype.none, with: nil)

        #expect(received.withLock { $0 } == 1)
    }

    @Test("copying takes the request and the response together")
    func copyTextJoinsBothHalves() {
        let paired = RequestDetailView(entry: makeEntry(status: .success(200),
                                                        responseText: "Status Code: 200"))
        let cacheOnly = RequestDetailView(entry: makeEntry(kind: .cache, status: .cacheMiss))

        #expect(paired.copyText == "[Method]: POST\n\nStatus Code: 200")
        #expect(cacheOnly.copyText == "[Method]: POST")
    }

    @Test("the inspector draws its empty state and its rows")
    func inspectorDraws() async {
        let apiLog = APILogStore()
        let cacheLog = CacheLogStore()

        await render(NavigationStack { RequestInspectorView(apiLog: apiLog, cacheLog: cacheLog) })

        let request = makeRequest()
        apiLog.log(.request(request))
        apiLog.log(.response(makeResponse(for: request)))
        apiLog.log(.request(makeRequest(kind: .image)))
        cacheLog.log(CacheLogEvent(key: CacheKey(namespace: "characters", identifier: "page-1"),
                                   outcome: .hit(layer: .memory, isExpired: false)))

        await render(NavigationStack { RequestInspectorView(apiLog: apiLog, cacheLog: cacheLog) })
    }

    @Test("every row state draws")
    func rowsDraw() async {
        let statuses: [RequestInspectorEntry.Status] = [
            .pending,
            .success(200),
            .failure(429),
            .transportError,
            .cacheHit(isExpired: false, layer: "memory"),
            .cacheHit(isExpired: true, layer: "disk"),
            .cacheMiss
        ]

        await render(List(Array(statuses.enumerated()), id: \.offset) { _, status in
            RequestInspectorRow(entry: makeEntry(status: status))
        })
    }

    @Test("the detail view draws a paired call and a lone cache read")
    func detailDraws() async {
        await render(NavigationStack {
            RequestDetailView(entry: makeEntry(status: .success(200),
                                               responseText: "Status Code: 200"))
        })
        await render(NavigationStack {
            RequestDetailView(entry: makeEntry(kind: .cache, status: .cacheMiss))
        })
    }

    @Test("the shake modifier draws the view it wraps")
    func shakeModifierDraws() async {
        await render(
            Text("App")
                .devToolsOnShake(caches: [DevToolsCache(name: "Images") {}],
                                 apiLog: APILogStore(),
                                 cacheLog: CacheLogStore())
        )
    }

    // MARK: - Helpers

    private func observeClears(on center: NotificationCenter) -> ClearObserver {
        ClearObserver(center: center)
    }

    /// `@unchecked`: token written once in `init`, read once in `deinit`; names sit behind a `Mutex`.
    private final class ClearObserver: @unchecked Sendable {
        /// Captured by the observer closure without retaining `self`, so `deinit` still runs.
        private final class Recorder: Sendable {
            let names = Mutex<[[String]]>([])
        }

        private let recorder = Recorder()
        private let center: NotificationCenter
        private let token: NSObjectProtocol

        init(center: NotificationCenter) {
            self.center = center
            let recorder = recorder
            token = center.addObserver(forName: .cacheDidClear, object: nil, queue: nil) { notification in
                recorder.names.withLock { $0.append(CacheClearedNotification.cacheNames(from: notification)) }
            }
        }

        func names() -> [[String]] {
            recorder.names.withLock { $0 }
        }

        deinit {
            center.removeObserver(token)
        }
    }

    private func makeEntry(kind: RequestInspectorEntry.Kind = .api,
                           status: RequestInspectorEntry.Status,
                           responseText: String? = nil) -> RequestInspectorEntry {
        RequestInspectorEntry(
            id: UUID(),
            timestamp: Date(),
            kind: kind,
            title: "[POST] https://rickandmortyapi.com/graphql",
            status: status,
            duration: 0.25,
            requestText: "[Method]: POST",
            responseText: responseText
        )
    }

    private func makeRequest(kind: APILogKind = .api) -> APIRequestRecord {
        APIRequestRecord(kind: kind,
                         method: kind == .image ? "GET" : "POST",
                         url: URL(string: "https://rickandmortyapi.com/graphql")!,
                         headers: [:],
                         body: nil)
    }

    private func makeResponse(for request: APIRequestRecord) -> APIResponseRecord {
        APIResponseRecord(id: request.id, kind: request.kind, method: request.method,
                          url: request.url, outcome: .success(statusCode: 200),
                          headers: [:], body: nil, duration: 0.1)
    }

    /// Hosts `view` on a sized window and forces layout: an unhosted view never runs its `body`.
    private func render(_ view: some View) async {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()

        // `.task`-seeded views (the inspector) need more than one layout pass to draw their rows.
        for _ in 0..<10 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(50))

        window.layoutIfNeeded()
        window.isHidden = true
    }
}
