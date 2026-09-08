//
//  RequestInspectorModel.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Observation
import Storage

/// Merges the network and cache logs into one list for the inspector.
@MainActor
@Observable
final class RequestInspectorModel {

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case api = "API"
        case images = "Images"
        case cache = "Cache"

        var id: String { rawValue }

        func accepts(_ entry: RequestInspectorEntry) -> Bool {
            switch self {
            case .all: return true
            case .api: return entry.kind == .api
            case .images: return entry.kind == .image
            case .cache: return entry.kind == .cache
            }
        }
    }

    private(set) var entries: [RequestInspectorEntry] = []
    /// De-dupes an event seen twice (history + stream); duplicate ids make SwiftUI drop/reorder rows.
    private var knownIDs: Set<UUID> = []
    var filter: Filter = .all
    /// Case-insensitive match against ``RequestInspectorEntry/searchableText``. Blank means no search.
    var searchText = ""

    /// Newest first.
    var visibleEntries: [RequestInspectorEntry] {
        entries.filter { filter.accepts($0) && matchesSearch($0) }
    }

    /// Whether the search, not an empty log, is why the list is empty — the two need different states.
    var isSearchHidingEverything: Bool {
        visibleEntries.isEmpty && !searchQuery.isEmpty && entries.contains(where: filter.accepts)
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchesSearch(_ entry: RequestInspectorEntry) -> Bool {
        let query = searchQuery
        guard !query.isEmpty else { return true }
        return entry.searchableText.localizedCaseInsensitiveContains(query)
    }

    private let apiLog: APILogStore
    private let cacheLog: CacheLogStore
    private let apiFormatter = APILogFormatter()
    private let cacheFormatter = CacheLogFormatter()

    init(apiLog: APILogStore, cacheLog: CacheLogStore) {
        self.apiLog = apiLog
        self.cacheLog = cacheLog
    }

    /// Seeds from both histories, then follows both streams until cancelled. Subscribes to the
    /// streams before reading history so nothing logged in between is lost; `apply` dedupes the overlap.
    func start() async {
        let networkStream = apiLog.stream()
        let cacheStream = cacheLog.stream()

        entries.removeAll()
        knownIDs.removeAll()
        for event in apiLog.events {
            apply(event)
        }
        for event in cacheLog.events {
            apply(event)
        }
        sort()

        // Concurrent, not sequential: each stream runs until the screen goes away.
        async let network: Void = consume(networkStream)
        async let cache: Void = consume(cacheStream)
        _ = await (network, cache)
    }

    private func consume(_ stream: AsyncStream<APILogEvent>) async {
        for await event in stream {
            apply(event)
            sort()
        }
    }

    private func consume(_ stream: AsyncStream<CacheLogEvent>) async {
        for await event in stream {
            apply(event)
            sort()
        }
    }

    /// Empties the list and both underlying stores, not just the local list.
    func clear() {
        entries.removeAll()
        knownIDs.removeAll()
        apiLog.removeAll()
        cacheLog.removeAll()
    }

    private func apply(_ event: APILogEvent) {
        switch event {
        case .request(let record):
            guard knownIDs.insert(record.id).inserted else { return }
            entries.append(RequestInspectorEntry(request: record, formatter: apiFormatter))
        case .response(let record):
            guard let index = entries.firstIndex(where: { $0.id == record.id }) else {
                guard knownIDs.insert(record.id).inserted else { return }
                entries.append(RequestInspectorEntry(orphanResponse: record, formatter: apiFormatter))
                return
            }
            guard entries[index].responseText == nil else { return }
            entries[index] = entries[index].completed(with: record, formatter: apiFormatter)
        }
    }

    private func apply(_ event: CacheLogEvent) {
        guard knownIDs.insert(event.id).inserted else { return }
        entries.append(RequestInspectorEntry(cache: event, formatter: cacheFormatter))
    }

    private func sort() {
        entries.sort { $0.timestamp > $1.timestamp }
    }
}
