//
//  RequestInspectorView.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking
import Storage
import SwiftUI

/// The network and cache traffic, newest first.
struct RequestInspectorView: View {
    @State private var model: RequestInspectorModel

    init(apiLog: APILogStore, cacheLog: CacheLogStore) {
        _model = State(initialValue: RequestInspectorModel(apiLog: apiLog, cacheLog: cacheLog))
    }

    var body: some View {
        Group {
            if model.isSearchHidingEverything {
                ContentUnavailableView.search(text: model.searchText)
            } else if model.visibleEntries.isEmpty {
                ContentUnavailableView(
                    "Nothing logged yet",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Requests and cache reads appear here as they happen.")
                )
            } else {
                List(model.visibleEntries) { entry in
                    NavigationLink {
                        RequestDetailView(entry: entry)
                    } label: {
                        RequestInspectorRow(entry: entry)
                    }
                }
                .listStyle(.plain)
            }
        }
        .safeAreaInset(edge: .top) {
            Picker("Filter", selection: $model.filter) {
                ForEach(RequestInspectorModel.Filter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(.bar)
        }
        .navigationTitle("Requests")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $model.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search requests and responses"
        )
        // Queries are URLs, JSON keys and status codes; no autocapitalization or autocorrect.
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear", systemImage: "trash") {
                    model.clear()
                }
                .disabled(model.entries.isEmpty)
            }
        }
        .task { await model.start() }
    }
}

/// One line of traffic: what it was, when, where to, and how it ended.
struct RequestInspectorRow: View {
    let entry: RequestInspectorEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(Self.badge(for: entry.kind))
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Self.badgeColor(for: entry.kind).opacity(0.18), in: .rect(cornerRadius: 4))
                    .foregroundStyle(Self.badgeColor(for: entry.kind))

                Text(Self.time(entry.timestamp))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                if let duration = entry.duration {
                    Text("\(Int((duration * 1_000).rounded())) ms")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Text(entry.status.text)
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Self.statusColor(for: entry.status))
            }

            // Middle truncation: both the host (front) and resource (back) carry information.
            Text(entry.title)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }

    static func badge(for kind: RequestInspectorEntry.Kind) -> String {
        switch kind {
        case .api: return "API"
        case .image: return "IMG"
        case .cache: return "CACHE"
        }
    }

    static func badgeColor(for kind: RequestInspectorEntry.Kind) -> Color {
        switch kind {
        case .api: return .blue
        case .image: return .purple
        case .cache: return .teal
        }
    }

    /// A cache miss is not a failure, so it stays neutral rather than red.
    static func statusColor(for status: RequestInspectorEntry.Status) -> Color {
        switch status {
        case .pending:
            return .orange
        case .success:
            return .green
        case .failure, .transportError:
            return .red
        case .cacheHit(let isExpired, _):
            return isExpired ? .orange : .green
        case .cacheMiss:
            return .secondary
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
