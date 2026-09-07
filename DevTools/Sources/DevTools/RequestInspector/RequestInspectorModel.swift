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
///
/// `@Observable` and nothing else — no view model contract, no section mapper,
/// no publishers. The architecture the features use exists to keep a screen
/// testable while it grows; this screen is a debug tool that reads two arrays
/// and shows them, and the layers would be pure ceremony. See the README.
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
    /// Every identifier in `entries`, so an event that arrives twice — once in
    /// the history and once on the stream, or on a second `start()` — is
    /// recognised in constant time and added once. Duplicate identifiers in a
    /// `List` are not a cosmetic problem: SwiftUI drops and reorders rows.
    private var knownIDs: Set<UUID> = []
    var filter: Filter = .all
    /// Matched case-insensitively against each entry's whole text — title,
    /// request and response — see ``RequestInspectorEntry/searchableText``.
    /// Blank means no search.
    var searchText = ""

    /// Newest first: the thing a developer wants is almost always the last thing
    /// that happened, and a list that grows downwards would need scrolling to
    /// the bottom on every new event.
    var visibleEntries: [RequestInspectorEntry] {
        entries.filter { filter.accepts($0) && matchesSearch($0) }
    }

    /// Whether the list is empty because of the search rather than because
    /// nothing has been logged — the two deserve different empty states.
    var isSearchHidingEverything: Bool {
        visibleEntries.isEmpty && !searchQuery.isEmpty && entries.contains(where: filter.accepts)
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A plain substring match over the full text. Response bodies run to tens
    /// of kilobytes and there can be a thousand entries, and that is still a
    /// few milliseconds per keystroke — not worth an index for a debug screen.
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

    /// Seeds from both histories, then follows both streams until cancelled.
    ///
    /// Safe to run more than once on the same model, and it will be: the view
    /// starts it from `.task`, which fires every time the inspector appears —
    /// after a detail row is popped, and sometimes twice during the sheet's own
    /// presentation. Each run starts from an empty list, so a second seeding
    /// cannot stack a second copy of every row on top of the first.
    ///
    /// The streams are subscribed *before* the history is read, not after. A
    /// stream starts at the moment of subscription, so subscribing afterwards
    /// would lose anything logged while the history was being copied. The
    /// price of subscribing first is that an event logged in that window
    /// arrives twice — once from the history, once from the stream — and
    /// `apply` recognises it by id and keeps one.
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

        // Two child tasks rather than two sequential loops: each stream runs
        // until the screen goes away, so one after the other would never reach
        // the second. Both stay on the main actor — they write `entries`, which
        // the view observes — and interleave at each `await`.
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

    /// Empties the list and both stores.
    ///
    /// Clearing the stores too, rather than only the local list, is what makes
    /// the button useful: leaving the history behind would mean the next screen
    /// to open the inspector sees everything this one just dismissed.
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
            // A response seen twice is the overlap described in `start()`; the
            // entry is already complete and the second copy has nothing to add.
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
