//
//  DevToolsScreen.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking
import Storage
import SwiftUI

/// The debug menu: clear a cache, or read the traffic.
///
/// Deliberately built with none of the app's architecture — no `*Contract`
/// protocols, no section mappers, no use cases, no view model per screen. Those
/// exist so a feature can grow without its screens becoming untestable, and this
/// is a tool that will never ship to a user: a `List` over an array of closures
/// and one `@Observable` for the inspector is the entire thing. Adding four
/// layers to it would cost more to read than the screen it wraps. See the
/// README's "Developer tools and logging".
public struct DevToolsScreen: View {
    private let caches: [DevToolsCache]
    private let apiLog: APILogStore
    private let cacheLog: CacheLogStore

    @Environment(\.dismiss) private var dismiss
    @State private var model = DevToolsCachesModel()

    public init(caches: [DevToolsCache], apiLog: APILogStore, cacheLog: CacheLogStore) {
        self.caches = caches
        self.apiLog = apiLog
        self.cacheLog = cacheLog
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Caches") {
                    Button {
                        Task { await model.clearAll(caches) }
                    } label: {
                        Label("Clear all caches", systemImage: "trash")
                    }
                    .disabled(model.isClearing || caches.isEmpty)

                    ForEach(caches) { cache in
                        row(for: cache)
                    }
                }

                Section("Requests") {
                    NavigationLink {
                        RequestInspectorView(apiLog: apiLog, cacheLog: cacheLog)
                    } label: {
                        Label("Request inspector", systemImage: "arrow.left.arrow.right")
                    }
                }
            }
            .navigationTitle("Developer tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(for cache: DevToolsCache) -> some View {
        Button {
            Task { await model.clear(cache) }
        } label: {
            HStack {
                Label("Clear \(cache.name) cache", systemImage: "trash")
                Spacer()
                result(for: cache)
            }
        }
        .disabled(model.isClearing)
    }

    @ViewBuilder
    private func result(for cache: DevToolsCache) -> some View {
        switch model.results[cache.id] {
        case .cleared:
            // A checkmark rather than an alert: clearing a cache is not a
            // decision anyone needs confirmed, and a sheet on top of a debug
            // sheet is two taps to get back to where you were.
            Label("Cleared", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.footnote)
                .foregroundStyle(.green)
        case .failed(let description):
            Text(description)
                .font(.footnote)
                .foregroundStyle(.red)
                .lineLimit(2)
        case nil:
            EmptyView()
        }
    }
}
