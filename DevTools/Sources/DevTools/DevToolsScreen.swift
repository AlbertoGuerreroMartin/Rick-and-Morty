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
