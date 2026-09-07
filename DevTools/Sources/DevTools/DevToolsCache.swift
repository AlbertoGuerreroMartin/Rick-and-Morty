//
//  DevToolsCache.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import DesignSystem
import Foundation

/// One clearable cache, as the debug screen sees it: a name to show and a
/// closure to run.
///
/// A closure rather than a protocol because there is nothing to abstract. Each
/// feature already knows how to wipe its own namespace — and keeps that
/// namespace private, which is the point — so the only thing this package needs
/// is somewhere to put the call. A `CacheClearingContract` with one method would
/// be the same closure with more ceremony and a conformance in every feature.
///
/// The list is supplied by the app's container, so adding a cache to the screen
/// is one line there and no change at all here.
public struct DevToolsCache: Identifiable, Sendable {
    /// The name doubles as the identity: two caches called "Characters" would be
    /// indistinguishable to whoever is reading the list anyway.
    public var id: String { name }
    public let name: String
    public let clear: @Sendable () async throws -> Void

    public init(name: String, clear: @escaping @Sendable () async throws -> Void) {
        self.name = name
        self.clear = clear
    }

    /// The image caches, both layers.
    ///
    /// Memory first, then disk: clearing disk alone would leave every visible
    /// avatar on screen, which reads as "the button did nothing". This one lives
    /// here rather than in the container because, unlike a feature's cache, the
    /// loader's API is public and there is no namespace to keep private.
    public static func images(loader: ImageLoader = .shared) -> DevToolsCache {
        DevToolsCache(name: "Images") {
            loader.clearMemoryCache()
            try await loader.clearDiskCache()
        }
    }
}
