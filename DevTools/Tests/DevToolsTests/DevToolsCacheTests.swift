//
//  DevToolsCacheTests.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Storage
import Synchronization
import Testing
import UIKit
@testable import DesignSystem
@testable import DevTools

@Suite("DevToolsCache")
struct DevToolsCacheTests {

    @Test("the name is the identity")
    func nameIsTheIdentity() {
        let cache = DevToolsCache(name: "Characters") {}

        #expect(cache.id == "Characters")
    }

    @Test("clearing runs the closure it was given")
    func clearRunsTheClosure() async throws {
        let ran = Mutex(false)
        let cache = DevToolsCache(name: "Characters") { ran.withLock { $0 = true } }

        try await cache.clear()

        #expect(ran.withLock { $0 })
    }

    @Test("a failure propagates to the caller")
    func failurePropagates() async {
        struct Failure: Error {}
        let cache = DevToolsCache(name: "Characters") { throw Failure() }

        await #expect(throws: Failure.self) { try await cache.clear() }
    }

    /// Both layers, in order: clearing disk alone would leave every avatar on
    /// screen and read as a button that did nothing.
    @Test("the images cache clears memory and disk")
    func imagesCacheClearsBothLayers() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let url = URL(string: "https://example.com/dev-tools-avatar.png")!
        let diskStore = FileDiskStore(root: directory.url)
        let diskCache = ImageDiskCache(diskStore: diskStore)
        // Seeded on disk rather than downloaded: the loader decodes a disk entry
        // through exactly the same path as a fresh download, so this warms both
        // layers without a stubbed network.
        try await diskCache.store(makePNG(), for: url)
        let loader = ImageLoader(session: URLSession(configuration: .ephemeral), diskCache: diskCache)
        _ = try await loader.image(for: url, maxPixelSize: 64)
        #expect(loader.cachedImage(for: url, maxPixelSize: 64) != nil)
        #expect(try await diskStore.entries(in: "images").isEmpty == false)

        try await DevToolsCache.images(loader: loader).clear()

        #expect(loader.cachedImage(for: url, maxPixelSize: 64) == nil)
        #expect(try await diskStore.entries(in: "images").isEmpty)
    }

    @Test("the images cache is named")
    func imagesCacheIsNamed() {
        #expect(DevToolsCache.images().name == "Images")
    }

    // MARK: - Helpers

    private func makePNG() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 128, height: 128)
        return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

/// A unique directory per test, so the suite never touches the app's real image
/// cache under `Library/Caches`.
struct TemporaryDirectory {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
