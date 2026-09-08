//
//  DevToolsCache.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import DesignSystem
import Foundation

/// One clearable cache, as the debug screen sees it: a name to show and a closure to run.
public struct DevToolsCache: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let clear: @Sendable () async throws -> Void

    public init(name: String, clear: @escaping @Sendable () async throws -> Void) {
        self.name = name
        self.clear = clear
    }

    /// Clears memory before disk: disk-only would leave visible images still cached in memory.
    public static func images(loader: ImageLoader = .shared) -> DevToolsCache {
        DevToolsCache(name: "Images") {
            loader.clearMemoryCache()
            try await loader.clearDiskCache()
        }
    }
}
