//
//  CachedAsyncImageTests.swift
//  DesignSystem
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Storage
import SwiftUI
import Testing
import UIKit
@testable import DesignSystem

/// SwiftUI bodies are lazy, so the view is hosted on a sized window and laid out
/// — building the value alone would run neither `body` nor the `.task`.
@Suite("CachedAsyncImage", .serialized)
@MainActor
struct CachedAsyncImageTests {

    @Test("an appearance loads the image and logs exactly one cache event")
    func oneEventPerAppearance() async throws {
        let url = URL(string: "https://example.com/cached-async-first.png")!
        StubURLProtocol.stub(url, with: .init(data: makePNG()))
        let cache = SpyImageCacheSink()
        let loader = makeLoader(cache: cache)

        await render(CachedAsyncImage(url: url, maxPixelSize: 64, loader: loader))

        #expect(cache.outcomes == [.miss])
    }

    /// The synchronous read in `init` now adopts the bitmap *and* falls through
    /// to the loader, so a warm appearance still logs its hit — the busiest path
    /// in the app used to be invisible in the inspector.
    @Test("a warm appearance still logs its memory hit")
    func warmAppearanceLogsAHit() async throws {
        let url = URL(string: "https://example.com/cached-async-warm.png")!
        StubURLProtocol.stub(url, with: .init(data: makePNG()))
        let cache = SpyImageCacheSink()
        let loader = makeLoader(cache: cache)
        _ = try await loader.image(for: url, maxPixelSize: 64)
        let outcomesBeforeAppearance = cache.outcomes.count

        await render(CachedAsyncImage(url: url, maxPixelSize: 64, loader: loader))

        #expect(cache.outcomes.dropFirst(outcomesBeforeAppearance)
                == [.hit(layer: .memory, isExpired: false)])
    }

    @Test("a nil URL draws the placeholder and loads nothing")
    func nilURLDrawsThePlaceholder() async {
        let cache = SpyImageCacheSink()

        await render(CachedAsyncImage(url: nil, maxPixelSize: 64, loader: makeLoader(cache: cache)))

        #expect(cache.outcomes.isEmpty)
    }

    @Test("a load that fails leaves the placeholder in place")
    func failedLoadDraws() async {
        let url = URL(string: "https://example.com/cached-async-missing.png")!
        StubURLProtocol.stub(url, with: .init(statusCode: 404, data: Data()))

        await render(CachedAsyncImage(url: url, maxPixelSize: 64, loader: makeLoader()) { image in
            image.resizable()
        } placeholder: {
            Color.gray
        })
    }

    // MARK: - Helpers

    private func makeLoader(cache: any CacheLogSinkContract = NoOpCacheLogger()) -> ImageLoader {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return ImageLoader(
            session: URLSession(configuration: configuration),
            diskCache: ImageDiskCache(diskStore: FileDiskStore(root: TemporaryDirectory().url)),
            cacheLogger: cache
        )
    }

    /// Hosts `view` on a sized window and forces layout, so its `body` runs and
    /// its `.task` starts. A hosting controller with no window lays out nothing.
    private func render(_ view: some View) async {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()

        // The `.task` is asynchronous and goes through the loader's actor and a
        // detached download, so layout returning is not enough.
        for _ in 0..<20 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(120))

        window.layoutIfNeeded()
        window.isHidden = true
    }

    private func makePNG() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 128, height: 128)
        return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
