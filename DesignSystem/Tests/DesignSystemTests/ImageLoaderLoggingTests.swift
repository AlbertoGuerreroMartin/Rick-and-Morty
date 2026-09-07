//
//  ImageLoaderLoggingTests.swift
//  DesignSystem
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Storage
import Testing
import UIKit
@testable import DesignSystem

/// The logs are what a developer reads to answer "why did this avatar come from
/// the network again", so what matters is that each of the three paths — memory,
/// disk, network — produces exactly one distinguishable event.
@Suite("ImageLoader logging")
struct ImageLoaderLoggingTests {

    @Test("a cold load logs a cache miss, an image request and its response")
    func coldLoadLogsTheDownload() async throws {
        let url = URL(string: "https://example.com/log-cold.png")!
        let payload = makePNG(sideLength: 128)
        StubURLProtocol.stub(url, with: .init(data: payload))
        let network = SpyAPISink()
        let cache = SpyImageCacheSink()
        let loader = makeLoader(network: network, cache: cache)

        _ = try await loader.image(for: url, maxPixelSize: 64)

        #expect(cache.outcomes == [.miss])
        #expect(cache.events.first?.key == CacheKey(namespace: "images",
                                                    identifier: url.absoluteString))

        let request = try #require(network.requests.first)
        #expect(request.kind == .image)
        #expect(request.method == "GET")
        #expect(request.url == url)

        let response = try #require(network.responses.first)
        #expect(response.id == request.id)
        #expect(response.kind == .image)
        #expect(response.outcome == .success(statusCode: 200))
        #expect(response.body == payload)
        #expect(response.duration >= 0)
    }

    @Test("a second load of the same image logs a memory hit and no request")
    func memoryHitLogsNoRequest() async throws {
        let url = URL(string: "https://example.com/log-memory.png")!
        StubURLProtocol.stub(url, with: .init(data: makePNG(sideLength: 128)))
        let network = SpyAPISink()
        let cache = SpyImageCacheSink()
        let loader = makeLoader(network: network, cache: cache)

        _ = try await loader.image(for: url, maxPixelSize: 64)
        let requestsAfterFirstLoad = network.requests.count
        _ = try await loader.image(for: url, maxPixelSize: 64)

        #expect(cache.outcomes == [.miss, .hit(layer: .memory, isExpired: false)])
        #expect(network.requests.count == requestsAfterFirstLoad)
    }

    /// A fresh loader over the same directory is what a relaunch looks like:
    /// nothing in memory, the bytes still on disk.
    @Test("a relaunch logs a disk hit and no request")
    func diskHitLogsNoRequest() async throws {
        let url = URL(string: "https://example.com/log-disk.png")!
        StubURLProtocol.stub(url, with: .init(data: makePNG(sideLength: 128)))
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        _ = try await makeLoader(diskCache: makeDiskCache(root: directory.url))
            .image(for: url, maxPixelSize: 64)

        let network = SpyAPISink()
        let cache = SpyImageCacheSink()
        let second = makeLoader(diskCache: makeDiskCache(root: directory.url),
                                network: network,
                                cache: cache)
        _ = try await second.image(for: url, maxPixelSize: 64)

        #expect(cache.outcomes == [.hit(layer: .disk, isExpired: false)])
        #expect(network.requests.isEmpty)
    }

    /// The response is logged *before* the status is turned into an error, so a
    /// failed load shows a finished entry rather than one stuck on PENDING.
    @Test("a non-2xx status is logged as a failure response")
    func failureIsLogged() async throws {
        let url = URL(string: "https://example.com/log-missing.png")!
        StubURLProtocol.stub(url, with: .init(statusCode: 404, data: Data()))
        let network = SpyAPISink()
        let loader = makeLoader(network: network)

        _ = try? await loader.image(for: url, maxPixelSize: 64)

        let response = try #require(network.responses.first)
        #expect(response.outcome == .failure(statusCode: 404))
        #expect(response.kind == .image)
    }

    @Test("clearing the disk cache sends the next load back to the network")
    func clearDiskCacheForcesADownload() async throws {
        let url = URL(string: "https://example.com/log-cleared.png")!
        StubURLProtocol.stub(url, with: .init(data: makePNG(sideLength: 128)))
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let diskCache = makeDiskCache(root: directory.url)
        _ = try await makeLoader(diskCache: diskCache).image(for: url, maxPixelSize: 64)

        try await makeLoader(diskCache: diskCache).clearDiskCache()
        #expect(try await diskCache.data(for: url) == nil)

        // A third loader, so the assertion is about the disk and not about a
        // memory cache that would have answered anyway.
        let network = SpyAPISink()
        let cache = SpyImageCacheSink()
        _ = try await makeLoader(diskCache: makeDiskCache(root: directory.url),
                                 network: network,
                                 cache: cache)
            .image(for: url, maxPixelSize: 64)

        #expect(cache.outcomes == [.miss])
        #expect(network.requests.count == 1)
    }

    /// The loggers are installed after construction, because `ImageLoader.shared`
    /// exists before the app container does.
    @Test("setLoggers redirects an already-built loader")
    func setLoggersAppliesToTheSharedLoader() async throws {
        let url = URL(string: "https://example.com/log-setloggers.png")!
        StubURLProtocol.stub(url, with: .init(data: makePNG(sideLength: 128)))
        let loader = makeLoader()
        let network = SpyAPISink()
        let cache = SpyImageCacheSink()

        loader.setLoggers(network: network, cache: cache)
        _ = try await loader.image(for: url, maxPixelSize: 64)

        #expect(cache.outcomes == [.miss])
        #expect(network.requests.count == 1)
    }

    // MARK: - Helpers

    private func makeLoader(diskCache: (any ImageDiskCacheContract)? = nil,
                            network: any APILogSinkContract = NoOpAPILogger(),
                            cache: any CacheLogSinkContract = NoOpCacheLogger()) -> ImageLoader {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return ImageLoader(
            session: URLSession(configuration: configuration),
            diskCache: diskCache ?? makeDiskCache(root: TemporaryDirectory().url),
            networkLogger: network,
            cacheLogger: cache
        )
    }

    private func makeDiskCache(root: URL) -> ImageDiskCache {
        ImageDiskCache(diskStore: FileDiskStore(root: root))
    }

    private func makePNG(sideLength: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: sideLength, height: sideLength)
        return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
