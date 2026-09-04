import Foundation
import Storage
import Testing
import UIKit
@testable import DesignSystem

@Suite("ImageLoader")
struct ImageLoaderTests {

    @Test("decodes and caches, then answers synchronously")
    func cachesDecodedImage() async throws {
        let url = URL(string: "https://example.com/a.png")!
        StubURLProtocol.stub(url, with: .init(data: makePNG(sideLength: 256)))
        let loader = makeLoader()

        #expect(loader.cachedImage(for: url, maxPixelSize: 64) == nil)

        _ = try await loader.image(for: url, maxPixelSize: 64)

        // The synchronous peek is what lets a recycled row draw on frame one.
        #expect(loader.cachedImage(for: url, maxPixelSize: 64) != nil)
    }

    @Test("a second request for a cached image does not hit the network")
    func servesSecondRequestFromMemory() async throws {
        let url = URL(string: "https://example.com/b.png")!
        StubURLProtocol.stub(url, with: .init(data: makePNG(sideLength: 256)))
        let loader = makeLoader()

        _ = try await loader.image(for: url, maxPixelSize: 64)
        _ = try await loader.image(for: url, maxPixelSize: 64)

        #expect(StubURLProtocol.requestCount(for: url) == 1)
    }

    @Test("concurrent requests for the same image share one download")
    func coalescesConcurrentRequests() async throws {
        let url = URL(string: "https://example.com/c.png")!
        // The delay keeps the first request in flight long enough for the rest
        // to arrive, which is the situation a fast scroll actually creates.
        StubURLProtocol.stub(url, with: .init(data: makePNG(sideLength: 256), delay: 0.3))
        let loader = makeLoader()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { _ = try await loader.image(for: url, maxPixelSize: 64) }
            }
            try await group.waitForAll()
        }

        #expect(StubURLProtocol.requestCount(for: url) == 1)
    }

    @Test("downsamples to the requested longest edge")
    func downsamplesToTargetSize() async throws {
        let url = URL(string: "https://example.com/d.png")!
        StubURLProtocol.stub(url, with: .init(data: makePNG(sideLength: 512)))
        let loader = makeLoader()

        let image = try await loader.image(for: url, maxPixelSize: 64)

        let cgImage = try #require(image.cgImage)
        #expect(max(cgImage.width, cgImage.height) == 64)
    }

    @Test("the same URL at two sizes yields two cache entries")
    func sizeIsPartOfCacheIdentity() async throws {
        let url = URL(string: "https://example.com/e.png")!
        StubURLProtocol.stub(url, with: .init(data: makePNG(sideLength: 512)))
        let loader = makeLoader()

        let small = try await loader.image(for: url, maxPixelSize: 64)
        let large = try await loader.image(for: url, maxPixelSize: 256)

        // Reusing the 64px bitmap for the 256px request would ship a blurry
        // image, so the second request must genuinely re-decode.
        #expect(small.cgImage?.width == 64)
        #expect(large.cgImage?.width == 256)
        // Re-decode, not re-download: the encoded bytes are on disk after the
        // first request, and both sizes are decoded from that same file.
        #expect(StubURLProtocol.requestCount(for: url) == 1)
    }

    @Test("clearing memory drops decoded images")
    func clearMemoryCacheEvicts() async throws {
        let url = URL(string: "https://example.com/f.png")!
        StubURLProtocol.stub(url, with: .init(data: makePNG(sideLength: 256)))
        let loader = makeLoader()

        _ = try await loader.image(for: url, maxPixelSize: 64)
        loader.clearMemoryCache()

        #expect(loader.cachedImage(for: url, maxPixelSize: 64) == nil)
    }

    @Test("surfaces a non-success status code")
    func throwsOnHTTPError() async throws {
        let url = URL(string: "https://example.com/missing.png")!
        StubURLProtocol.stub(url, with: .init(statusCode: 404, data: Data()))
        let loader = makeLoader()

        await #expect(throws: ImageLoadingError.unacceptableStatusCode(404)) {
            _ = try await loader.image(for: url, maxPixelSize: 64)
        }
    }

    @Test("surfaces data that is not an image")
    func throwsOnUndecodableData() async throws {
        let url = URL(string: "https://example.com/garbage.png")!
        StubURLProtocol.stub(url, with: .init(data: Data("not an image".utf8)))
        let loader = makeLoader()

        await #expect(throws: ImageLoadingError.undecodableData) {
            _ = try await loader.image(for: url, maxPixelSize: 64)
        }
    }

    @Test("a failed load does not poison the next attempt")
    func retriesAfterFailure() async throws {
        let url = URL(string: "https://example.com/flaky.png")!
        StubURLProtocol.stub(url, with: .init(statusCode: 500, data: Data()))
        let loader = makeLoader()

        _ = try? await loader.image(for: url, maxPixelSize: 64)

        StubURLProtocol.stub(url, with: .init(data: makePNG(sideLength: 256)))
        let image = try await loader.image(for: url, maxPixelSize: 64)

        #expect(image.cgImage != nil)
    }

    @Test("a fresh loader over the same directory needs no network at all")
    func servesFromDiskAcrossLoaderInstances() async throws {
        let url = URL(string: "https://example.com/persisted.png")!
        StubURLProtocol.stub(url, with: .init(data: makePNG(sideLength: 256)))
        let directory = TemporaryDirectory()
        defer { directory.remove() }

        let first = makeLoader(diskCache: makeDiskCache(root: directory.url))
        _ = try await first.image(for: url, maxPixelSize: 64)
        let downloads = StubURLProtocol.requestCount(for: url)

        // A second loader over the same directory is what a relaunch looks like:
        // empty memory cache, the bytes still on disk.
        let second = makeLoader(diskCache: makeDiskCache(root: directory.url))
        let image = try await second.image(for: url, maxPixelSize: 64)

        #expect(image.cgImage?.width == 64)
        #expect(StubURLProtocol.requestCount(for: url) == downloads)
    }

    @Test("a disk cache that fails outright still lets the network path work")
    func survivesDiskCacheFailure() async throws {
        let url = URL(string: "https://example.com/nodisk.png")!
        StubURLProtocol.stub(url, with: .init(data: makePNG(sideLength: 256)))
        // A full disk, a revoked container, a corrupt directory: the image still
        // has to arrive. The cache is an optimisation, not a dependency.
        let loader = makeLoader(diskCache: FailingImageDiskCache())

        let image = try await loader.image(for: url, maxPixelSize: 64)

        #expect(image.cgImage?.width == 64)
    }

    // MARK: - Helpers

    /// - Parameter diskCache: defaults to a cache rooted in a directory of this
    ///   test's own. The loader's production disk cache is a real, shared path
    ///   under `Library/Caches`, and suites pointed at it would see each other's
    ///   files and pass or fail depending on execution order.
    private func makeLoader(diskCache: (any ImageDiskCacheContract)? = nil) -> ImageLoader {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        // No URL-level caching here: these tests are about the loader's own
        // layers, and a URLCache hit would mask a missing one of those.
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return ImageLoader(
            session: URLSession(configuration: configuration),
            diskCache: diskCache ?? makeDiskCache(root: TemporaryDirectory().url)
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
            UIColor.systemPink.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
