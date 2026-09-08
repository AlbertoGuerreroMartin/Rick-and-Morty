//
//  RequestInspectorModelTests.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Storage
import Testing
@testable import DevTools

@Suite("RequestInspectorModel")
@MainActor
struct RequestInspectorModelTests {

    private let url = URL(string: "https://rickandmortyapi.com/graphql")!

    @Test("seeds from both histories before anything new arrives")
    func seedsFromHistory() async {
        let apiLog = APILogStore()
        let cacheLog = CacheLogStore()
        let request = makeRequest()
        apiLog.log(.request(request))
        apiLog.log(.response(makeResponse(for: request)))
        cacheLog.log(makeCacheEvent())
        let model = RequestInspectorModel(apiLog: apiLog, cacheLog: cacheLog)

        await start(model)

        #expect(model.entries.count == 2)
        #expect(model.entries.contains { $0.kind == .api && $0.status == .success(200) })
        #expect(model.entries.contains { $0.kind == .cache })
    }

    @Test("a live response fills in the request it belongs to")
    func responseUpdatesTheRequestInPlace() async {
        let apiLog = APILogStore()
        let model = RequestInspectorModel(apiLog: apiLog, cacheLog: CacheLogStore())
        let task = Task { await model.start() }
        defer { task.cancel() }
        await settle()

        let request = makeRequest()
        apiLog.log(.request(request))
        await settle()
        #expect(model.entries.map(\.status) == [.pending])
        #expect(model.entries.first?.responseText == nil)

        apiLog.log(.response(makeResponse(for: request, duration: 0.25)))
        await settle()

        #expect(model.entries.count == 1)
        #expect(model.entries.first?.status == .success(200))
        #expect(model.entries.first?.duration == 0.25)
        #expect(model.entries.first?.responseText != nil)
    }

    /// The store's cap drops oldest events, so a mid-scroll open really can see this.
    @Test("a response with no request becomes its own entry")
    func orphanResponseBecomesAnEntry() async {
        let apiLog = APILogStore()
        apiLog.log(.response(makeResponse(for: makeRequest())))
        let model = RequestInspectorModel(apiLog: apiLog, cacheLog: CacheLogStore())

        await start(model)

        #expect(model.entries.count == 1)
        #expect(model.entries.first?.status == .success(200))
        #expect(model.entries.first?.requestText.contains("no longer in the log") == true)
    }

    @Test("a cache event becomes a row with its key and outcome")
    func cacheEventBecomesARow() async {
        let cacheLog = CacheLogStore()
        cacheLog.log(CacheLogEvent(key: CacheKey(namespace: "characters", identifier: "page-1"),
                                   outcome: .hit(layer: .disk, isExpired: true)))
        let model = RequestInspectorModel(apiLog: APILogStore(), cacheLog: cacheLog)

        await start(model)

        let entry = model.entries.first
        #expect(entry?.kind == .cache)
        #expect(entry?.title == "characters › page-1")
        #expect(entry?.status == .cacheHit(isExpired: true, layer: "disk"))
        #expect(entry?.responseText == nil)
    }

    @Test("entries are ordered newest first")
    func newestFirst() async {
        let apiLog = APILogStore()
        let cacheLog = CacheLogStore()
        apiLog.log(.request(makeRequest(timestamp: Date(timeIntervalSince1970: 100))))
        cacheLog.log(makeCacheEvent(timestamp: Date(timeIntervalSince1970: 300)))
        apiLog.log(.request(makeRequest(timestamp: Date(timeIntervalSince1970: 200))))
        let model = RequestInspectorModel(apiLog: apiLog, cacheLog: cacheLog)

        await start(model)

        #expect(model.entries.map(\.timestamp) == [
            Date(timeIntervalSince1970: 300),
            Date(timeIntervalSince1970: 200),
            Date(timeIntervalSince1970: 100)
        ])
    }

    @Test("a completed entry keeps its position")
    func completedEntryKeepsItsTimestamp() async {
        let apiLog = APILogStore()
        let request = makeRequest(timestamp: Date(timeIntervalSince1970: 100))
        apiLog.log(.request(request))
        apiLog.log(.request(makeRequest(timestamp: Date(timeIntervalSince1970: 200))))
        apiLog.log(.response(makeResponse(for: request,
                                          timestamp: Date(timeIntervalSince1970: 300))))
        let model = RequestInspectorModel(apiLog: apiLog, cacheLog: CacheLogStore())

        await start(model)

        #expect(model.entries.map(\.timestamp) == [
            Date(timeIntervalSince1970: 200),
            Date(timeIntervalSince1970: 100)
        ])
    }

    @Test("each filter shows only its own kind")
    func filters() async {
        let apiLog = APILogStore()
        let cacheLog = CacheLogStore()
        apiLog.log(.request(makeRequest()))
        apiLog.log(.request(makeRequest(kind: .image)))
        cacheLog.log(makeCacheEvent())
        let model = RequestInspectorModel(apiLog: apiLog, cacheLog: cacheLog)
        await start(model)

        #expect(model.visibleEntries.count == 3)

        model.filter = .api
        #expect(model.visibleEntries.map(\.kind) == [.api])

        model.filter = .images
        #expect(model.visibleEntries.map(\.kind) == [.image])

        model.filter = .cache
        #expect(model.visibleEntries.map(\.kind) == [.cache])

        model.filter = .all
        #expect(model.visibleEntries.count == 3)
    }

    @Test("clear empties the list and both stores")
    func clearEmptiesEverything() async {
        let apiLog = APILogStore()
        let cacheLog = CacheLogStore()
        apiLog.log(.request(makeRequest()))
        cacheLog.log(makeCacheEvent())
        let model = RequestInspectorModel(apiLog: apiLog, cacheLog: cacheLog)
        await start(model)

        model.clear()

        #expect(model.entries.isEmpty)
        #expect(apiLog.events.isEmpty)
        #expect(cacheLog.events.isEmpty)
    }

    @Test("a live cache event arrives through the stream")
    func liveCacheEvent() async {
        let cacheLog = CacheLogStore()
        let model = RequestInspectorModel(apiLog: APILogStore(), cacheLog: cacheLog)
        let task = Task { await model.start() }
        defer { task.cancel() }
        await settle()

        cacheLog.log(CacheLogEvent(key: CacheKey(namespace: "images", identifier: "a.jpeg"),
                                   outcome: .miss))
        await settle()

        #expect(model.entries.map(\.status) == [.cacheMiss])
    }

    @Test("an image request is labelled as an image, not as API")
    func imageKindIsPreserved() async {
        let apiLog = APILogStore()
        let request = makeRequest(kind: .image)
        apiLog.log(.request(request))
        apiLog.log(.response(makeResponse(for: request, kind: .image)))
        let model = RequestInspectorModel(apiLog: apiLog, cacheLog: CacheLogStore())

        await start(model)

        #expect(model.entries.map(\.kind) == [.image])
    }

    @Test("a transport error is shown as an error with no status code")
    func transportError() async {
        let apiLog = APILogStore()
        let request = makeRequest()
        apiLog.log(.request(request))
        apiLog.log(.response(APIResponseRecord(
            id: request.id, method: "POST", url: url,
            outcome: .transportError(description: "offline"),
            headers: [:], body: nil, duration: 0.1
        )))
        let model = RequestInspectorModel(apiLog: apiLog, cacheLog: CacheLogStore())

        await start(model)

        #expect(model.entries.map(\.status) == [.transportError])
    }

    @Test("a non-2xx response is shown as a failure with its status code")
    func failureStatus() async {
        let apiLog = APILogStore()
        let request = makeRequest()
        apiLog.log(.request(request))
        apiLog.log(.response(makeResponse(for: request, outcome: .failure(statusCode: 429))))
        let model = RequestInspectorModel(apiLog: apiLog, cacheLog: CacheLogStore())

        await start(model)

        #expect(model.entries.map(\.status) == [.failure(429)])
    }

    @Test("starting again on the same model does not duplicate the history")
    func restartingDoesNotDuplicate() async {
        let apiLog = APILogStore()
        let cacheLog = CacheLogStore()
        let request = makeRequest()
        apiLog.log(.request(request))
        apiLog.log(.response(makeResponse(for: request)))
        cacheLog.log(makeCacheEvent())
        let model = RequestInspectorModel(apiLog: apiLog, cacheLog: cacheLog)

        await start(model)
        let firstRun = model.entries
        await start(model)

        #expect(model.entries == firstRun)
        #expect(Set(model.entries.map(\.id)).count == model.entries.count)
    }

    @Test("an event seen in the history and again on the stream is one entry")
    func historyAndStreamOverlapIsOneEntry() async {
        let apiLog = APILogStore()
        let cacheLog = CacheLogStore()
        let request = makeRequest()
        let cacheEvent = makeCacheEvent()
        apiLog.log(.request(request))
        cacheLog.log(cacheEvent)
        let model = RequestInspectorModel(apiLog: apiLog, cacheLog: cacheLog)
        let task = Task { await model.start() }
        defer { task.cancel() }
        await settle()

        apiLog.log(.request(request))
        cacheLog.log(cacheEvent)
        apiLog.log(.response(makeResponse(for: request)))
        apiLog.log(.response(makeResponse(for: request)))
        await settle()

        #expect(model.entries.count == 2)
        #expect(model.entries.filter { $0.kind == .api }.map(\.status) == [.success(200)])
    }

    /// Covers timestamp ties: image events are logged by the dozen within one millisecond.
    @Test("two openings over the same history produce the same order")
    func orderIsDeterministic() async {
        let apiLog = APILogStore()
        let cacheLog = CacheLogStore()
        let timestamp = Date(timeIntervalSince1970: 100)
        for _ in 0..<20 {
            apiLog.log(.request(makeRequest(kind: .image, timestamp: timestamp)))
            cacheLog.log(makeCacheEvent(timestamp: timestamp))
        }
        let first = RequestInspectorModel(apiLog: apiLog, cacheLog: cacheLog)
        let second = RequestInspectorModel(apiLog: apiLog, cacheLog: cacheLog)

        await start(first)
        await start(second)

        #expect(first.entries.count == 40)
        #expect(first.entries.map(\.id) == second.entries.map(\.id))
    }

    @Test("the search matches request bodies, response bodies and titles, case-insensitively")
    func searchMatchesWholeText() async {
        let apiLog = APILogStore()
        let cacheLog = CacheLogStore()
        let characters = makeRequest(body: #"{"query":"query { characters { name } }","variables":{"name":"Rick"}}"#)
        apiLog.log(.request(characters))
        apiLog.log(.response(makeResponse(for: characters, body: Data(#"{"data":{"results":[{"name":"Morty Smith"}]}}"#.utf8))))
        let image = makeRequest(kind: .image, url: URL(string: "https://example.com/avatar/1.jpeg")!)
        apiLog.log(.request(image))
        cacheLog.log(CacheLogEvent(key: CacheKey(namespace: "episodes", identifier: "page-3"), outcome: .miss))
        let model = RequestInspectorModel(apiLog: apiLog, cacheLog: cacheLog)
        await start(model)

        model.searchText = "rick"                       // request variables, lower case
        #expect(model.visibleEntries.map(\.kind) == [.api])

        model.searchText = "MORTY SMITH"                // response body, upper case
        #expect(model.visibleEntries.map(\.kind) == [.api])

        model.searchText = "episodes › page-3"          // a cache entry's title
        #expect(model.visibleEntries.map(\.kind) == [.cache])

        model.searchText = "[GET]"                      // an image entry's title
        #expect(model.visibleEntries.map(\.kind) == [.image])

        model.searchText = "Status Code: 200"           // response header lines
        #expect(model.visibleEntries.map(\.kind) == [.api])

        model.searchText = "nothing like this"
        #expect(model.visibleEntries.isEmpty)
        #expect(model.isSearchHidingEverything)
    }

    @Test("a blank search shows everything and combines with the kind filter")
    func searchCombinesWithFilter() async {
        let apiLog = APILogStore()
        let cacheLog = CacheLogStore()
        apiLog.log(.request(makeRequest(url: URL(string: "https://rickandmortyapi.com/graphql")!)))
        apiLog.log(.request(makeRequest(kind: .image, url: URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")!)))
        cacheLog.log(makeCacheEvent())
        let model = RequestInspectorModel(apiLog: apiLog, cacheLog: cacheLog)
        await start(model)

        model.searchText = "   "
        #expect(model.visibleEntries.count == 3)
        #expect(model.isSearchHidingEverything == false)

        model.searchText = "rickandmortyapi"
        #expect(model.visibleEntries.count == 2)

        model.filter = .images
        #expect(model.visibleEntries.map(\.kind) == [.image])

        model.filter = .cache
        #expect(model.visibleEntries.isEmpty)
        #expect(model.isSearchHidingEverything)
    }

    // MARK: - Helpers

    private func makeRequest(kind: APILogKind = .api,
                             timestamp: Date = Date(),
                             url: URL? = nil,
                             body: String? = nil) -> APIRequestRecord {
        APIRequestRecord(timestamp: timestamp, kind: kind, method: kind == .image ? "GET" : "POST",
                         url: url ?? self.url, headers: [:], body: body.map { Data($0.utf8) })
    }

    private func makeResponse(for request: APIRequestRecord,
                              kind: APILogKind = .api,
                              outcome: APIResponseRecord.Outcome = .success(statusCode: 200),
                              timestamp: Date = Date(),
                              duration: TimeInterval = 0,
                              body: Data? = nil) -> APIResponseRecord {
        APIResponseRecord(id: request.id, timestamp: timestamp, kind: kind, method: request.method,
                          url: request.url, outcome: outcome, headers: [:], body: body, duration: duration)
    }

    private func makeCacheEvent(timestamp: Date = Date()) -> CacheLogEvent {
        CacheLogEvent(timestamp: timestamp,
                      key: CacheKey(namespace: "characters", identifier: "page-1"),
                      outcome: .miss)
    }

    /// Seeds the model from history, then cancels: `start()` never returns on its own.
    private func start(_ model: RequestInspectorModel) async {
        let task = Task { await model.start() }
        await settle()
        task.cancel()
    }

    /// Yields long enough for the stream consumers to pick an event up.
    private func settle() async {
        for _ in 0..<10 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(20))
    }
}
