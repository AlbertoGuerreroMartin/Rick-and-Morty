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

/// SwiftUI bodies are lazy: constructing a view runs no layout, so a crash in a
/// `body` survives every test that only builds the value. These host each view
/// in a real `UIHostingController` on a sized window and force a layout pass,
/// which is what actually evaluates the bodies.
///
/// Assertion-light on purpose. Snapshotting a debug screen's pixels would test
/// the system's rendering rather than anything this package decides; what is
/// worth knowing is that every state draws and that the one piece of behaviour
/// behind a button — clearing — reaches the closures it was given.
@Suite("DevTools views")
@MainActor
struct DevToolsViewTests {

    @Test("the screen draws with caches and with none")
    func screenDraws() async {
        await render(DevToolsScreen(caches: [DevToolsCache(name: "Characters") {},
                                             DevToolsCache(name: "Episodes") {}],
                                    apiLog: APILogStore(),
                                    cacheLog: CacheLogStore()))
        // An empty list is what a container that provides no caches produces,
        // and the "Clear all" row has to cope with it.
        await render(DevToolsScreen(caches: [], apiLog: APILogStore(), cacheLog: CacheLogStore()))
    }

    /// Driven through the model rather than by walking the UIKit hierarchy for a
    /// button whose identity SwiftUI does not promise — that would test the
    /// framework rather than this wiring.
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
        // The buttons come back enabled: a clear that left the list disabled
        // would need the screen dismissed and reopened to try again.
        #expect(model.isClearing == false)
        // One announcement for the whole tap, not one per cache: every screen
        // listening reloads on each post.
        #expect(announced.names() == [["Images", "Characters", "Episodes"]])
    }

    /// The screens showing cached data reload on this, and it is the only thing
    /// the tool ever says to them.
    @Test("clearing one cache announces that cache by name")
    func clearAnnouncesTheCache() async {
        let center = NotificationCenter()
        let announced = observeClears(on: center)
        let model = DevToolsCachesModel(notificationCenter: center)

        await model.clear(DevToolsCache(name: "Images") {})

        #expect(announced.names() == [["Images"]])
    }

    /// A cache that refuses to clear is exactly what this screen exists to
    /// surface, so the failure has to reach the row rather than be swallowed.
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
        // A cache that did not clear is not announced as cleared.
        #expect(announced.names() == [["Characters"]])
    }

    /// A clear that failed on every cache has nothing to announce: a reload
    /// would show the same cached data and look like the clear worked.
    @Test("a clear that fails everywhere announces nothing")
    func failedClearAnnouncesNothing() async {
        struct Failure: Error {}
        let center = NotificationCenter()
        let announced = observeClears(on: center)
        let model = DevToolsCachesModel(notificationCenter: center)

        await model.clearAll([DevToolsCache(name: "Images") { throw Failure() }])

        #expect(announced.names().isEmpty)
    }

    /// The row draws whatever the model last recorded, so both outcomes have to
    /// lay out — a `Text` of an error message next to a name is the case most
    /// likely to break the row.
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

    /// The shake is caught on the window, which is the only responder that
    /// exists no matter which screen — or sheet — is on top.
    @Test("shaking the window posts the notification the modifier listens for")
    func shakePostsTheNotification() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let received = Mutex(0)
        let token = NotificationCenter.default.addObserver(
            forName: .devToolsDeviceDidShake, object: nil, queue: nil
        ) { _ in received.withLock { $0 += 1 } }
        defer { NotificationCenter.default.removeObserver(token) }

        window.motionEnded(.motionShake, with: nil)
        // Any other motion has to pass straight through: the override is on
        // every window in the process, shake-to-undo included.
        window.motionEnded(UIEvent.EventSubtype.none, with: nil)

        #expect(received.withLock { $0 } == 1)
    }

    /// A request without its response is rarely enough to explain anything, so
    /// the copy button takes both halves.
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

    /// The shake modifier's own behaviour — a notification presenting a sheet —
    /// cannot be driven without a device, but the modified view still has to
    /// draw and its subscription still has to be installed.
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

    /// Records every `cacheDidClear` posted on `center` for as long as the
    /// returned observer lives.
    private func observeClears(on center: NotificationCenter) -> ClearObserver {
        ClearObserver(center: center)
    }

    /// `@unchecked`: the token is written once in `init` and read once in
    /// `deinit`, and the recorded names sit behind a `Mutex`.
    private final class ClearObserver: @unchecked Sendable {
        /// A reference the observer closure can capture without retaining the
        /// observer itself, so `deinit` still runs and unregisters the token.
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

    /// Hosts `view` on a sized window and forces layout, so its `body` actually
    /// runs. A hosting controller with no window lays out nothing.
    private func render(_ view: some View) async {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()

        // The inspector seeds itself from a `.task`, so layout returning once is
        // not enough to draw its rows.
        for _ in 0..<10 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(50))

        window.layoutIfNeeded()
        window.isHidden = true
    }
}
