//
//  RequestInspectorEntryTests.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Storage
import SwiftUI
import Testing
@testable import DevTools

/// `@MainActor` because it also exercises `RequestInspectorRow`'s static helpers, which SwiftUI isolates.
@Suite("RequestInspectorEntry")
@MainActor
struct RequestInspectorEntryTests {

    private let apiFormatter = APILogFormatter(timeZone: TimeZone(identifier: "UTC")!)
    private let cacheFormatter = CacheLogFormatter(timeZone: TimeZone(identifier: "UTC")!)
    private let url = URL(string: "https://rickandmortyapi.com/graphql")!

    @Test("a request becomes a pending entry titled with its method and URL")
    func requestBecomesPending() {
        let record = APIRequestRecord(method: "POST", url: url, headers: [:], body: nil)

        let entry = RequestInspectorEntry(request: record, formatter: apiFormatter)

        #expect(entry.id == record.id)
        #expect(entry.kind == .api)
        #expect(entry.title == "[POST] https://rickandmortyapi.com/graphql")
        #expect(entry.status == .pending)
        #expect(entry.duration == nil)
        #expect(entry.responseText == nil)
        #expect(entry.requestText == apiFormatter.string(for: record))
    }

    @Test("an image request is an image entry")
    func imageRequest() {
        let record = APIRequestRecord(kind: .image, method: "GET",
                                      url: URL(string: "https://example.com/a.jpeg")!,
                                      headers: [:], body: nil)

        #expect(RequestInspectorEntry(request: record, formatter: apiFormatter).kind == .image)
    }

    @Test("completing an entry keeps its identity and its start time")
    func completingKeepsIdentity() {
        let request = APIRequestRecord(timestamp: Date(timeIntervalSince1970: 100),
                                       method: "POST", url: url, headers: [:], body: nil)
        let response = APIResponseRecord(id: request.id,
                                         timestamp: Date(timeIntervalSince1970: 300),
                                         method: "POST", url: url,
                                         outcome: .success(statusCode: 200),
                                         headers: [:], body: nil, duration: 0.2)

        let entry = RequestInspectorEntry(request: request, formatter: apiFormatter)
            .completed(with: response, formatter: apiFormatter)

        #expect(entry.id == request.id)
        #expect(entry.timestamp == Date(timeIntervalSince1970: 100))
        #expect(entry.status == .success(200))
        #expect(entry.duration == 0.2)
        #expect(entry.responseText == apiFormatter.string(for: response))
    }

    @Test("an orphan response says its request is gone")
    func orphanResponse() {
        let response = APIResponseRecord(id: UUID(), method: "GET",
                                         url: URL(string: "https://example.com/a.jpeg")!,
                                         outcome: .failure(statusCode: 404),
                                         headers: [:], body: nil, duration: 0.1)

        let entry = RequestInspectorEntry(orphanResponse: response, formatter: apiFormatter)

        #expect(entry.status == .failure(404))
        #expect(entry.title == "[GET] https://example.com/a.jpeg")
        #expect(entry.requestText.contains("no longer in the log"))
        #expect(entry.responseText != nil)
    }

    @Test("a cache event puts its line in the request half")
    func cacheEvent() {
        let event = CacheLogEvent(key: CacheKey(namespace: "images", identifier: "a.jpeg"),
                                  outcome: .hit(layer: .disk, isExpired: false))

        let entry = RequestInspectorEntry(cache: event, formatter: cacheFormatter)

        #expect(entry.id == event.id)
        #expect(entry.kind == .cache)
        #expect(entry.title == "images › a.jpeg")
        #expect(entry.status == .cacheHit(isExpired: false, layer: "disk"))
        #expect(entry.requestText == cacheFormatter.string(for: event))
        #expect(entry.responseText == nil)
    }

    @Test("every status has a short label")
    func statusText() {
        #expect(RequestInspectorEntry.Status.pending.text == "PENDING")
        #expect(RequestInspectorEntry.Status.success(200).text == "200")
        #expect(RequestInspectorEntry.Status.failure(429).text == "429")
        #expect(RequestInspectorEntry.Status.transportError.text == "ERROR")
        #expect(RequestInspectorEntry.Status.cacheHit(isExpired: false, layer: "memory").text == "HIT")
        #expect(RequestInspectorEntry.Status.cacheHit(isExpired: true, layer: "disk").text == "HIT (expired)")
        #expect(RequestInspectorEntry.Status.cacheMiss.text == "MISS")
    }

    @Test("each kind has its own badge and colour")
    func badges() {
        #expect(RequestInspectorRow.badge(for: .api) == "API")
        #expect(RequestInspectorRow.badge(for: .image) == "IMG")
        #expect(RequestInspectorRow.badge(for: .cache) == "CACHE")

        let colors = [RequestInspectorEntry.Kind.api, .image, .cache].map(RequestInspectorRow.badgeColor)
        #expect(Set(colors).count == 3)
    }

    @Test("only genuine failures are red")
    func statusColors() {
        #expect(RequestInspectorRow.statusColor(for: .pending) == .orange)
        #expect(RequestInspectorRow.statusColor(for: .success(200)) == .green)
        #expect(RequestInspectorRow.statusColor(for: .failure(500)) == .red)
        #expect(RequestInspectorRow.statusColor(for: .transportError) == .red)
        #expect(RequestInspectorRow.statusColor(for: .cacheHit(isExpired: false, layer: "memory")) == .green)
        #expect(RequestInspectorRow.statusColor(for: .cacheHit(isExpired: true, layer: "disk")) == .orange)
        #expect(RequestInspectorRow.statusColor(for: .cacheMiss) == .secondary)
    }

    @Test("the row time is millisecond precision")
    func rowTime() {
        // 14:20:37.360 UTC; the formatter uses the reader's own time zone, so only shape is pinned.
        let text = RequestInspectorRow.time(Date(timeIntervalSince1970: 1_788_531_637.360))

        #expect(text.count == 12)
        #expect(text.hasSuffix(".360"))
    }

    @Test("every filter accepts only its own kind")
    func filterAcceptance() {
        let api = entry(kind: .api)
        let image = entry(kind: .image)
        let cache = entry(kind: .cache)

        #expect([api, image, cache].allSatisfy(RequestInspectorModel.Filter.all.accepts))
        #expect(RequestInspectorModel.Filter.api.accepts(api))
        #expect(!RequestInspectorModel.Filter.api.accepts(image))
        #expect(RequestInspectorModel.Filter.images.accepts(image))
        #expect(!RequestInspectorModel.Filter.images.accepts(cache))
        #expect(RequestInspectorModel.Filter.cache.accepts(cache))
        #expect(!RequestInspectorModel.Filter.cache.accepts(api))
        #expect(RequestInspectorModel.Filter.allCases.map(\.id) == ["All", "API", "Images", "Cache"])
    }

    private func entry(kind: RequestInspectorEntry.Kind) -> RequestInspectorEntry {
        RequestInspectorEntry(id: UUID(), timestamp: Date(), kind: kind, title: "",
                              status: .pending, duration: nil, requestText: "", responseText: nil)
    }
}
