import Foundation
import Networking
import Storage
import Synchronization
import UIKit

public enum ImageLoadingError: Error, Equatable {
    case undecodableData
    case unacceptableStatusCode(Int)
}

/// Loads, downsamples, and caches remote images, checking memory, then disk (``ImageDiskCache``), then network.
/// Concurrent requests for the same image are coalesced; use ``shared`` unless you need an isolated cache.
public actor ImageLoader {
    public static let shared = ImageLoader()

    /// Not isolated: `NSCache` is thread-safe, enabling synchronous main-thread reads.
    private nonisolated let memory: ImageMemoryCache

    private let session: URLSession
    private let diskCache: any ImageDiskCacheContract
    private var inFlight: [ImageKey: Task<UIImage, Error>] = [:]

    /// Not actor state: configured synchronously from `AppContainer.init` before any image loads.
    /// Wrapped in a class because `Mutex` is non-copyable and the detached download task must capture it.
    private struct Loggers: Sendable {
        var network: any APILogSinkContract
        var cache: any CacheLogSinkContract
    }

    private final class LoggerBox: Sendable {
        private let storage: Mutex<Loggers>

        init(network: any APILogSinkContract, cache: any CacheLogSinkContract) {
            storage = Mutex(Loggers(network: network, cache: cache))
        }

        var loggers: Loggers {
            storage.withLock { $0 }
        }

        func set(network: any APILogSinkContract, cache: any CacheLogSinkContract) {
            storage.withLock {
                $0.network = network
                $0.cache = cache
            }
        }
    }

    private nonisolated let loggerBox: LoggerBox

    public init(configuration: ImageLoaderConfiguration = .default) {
        let sessionConfiguration = URLSessionConfiguration.default
        // No `URLCache`: `ImageDiskCache` already holds the bytes; avoids a duplicate on-disk copy.
        sessionConfiguration.urlCache = nil
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData

        self.init(
            session: URLSession(configuration: sessionConfiguration),
            diskCache: ImageDiskCache(
                diskStore: FileDiskStore(),
                capacity: configuration.diskCapacity
            ),
            configuration: configuration
        )
    }

    /// For tests: injects a stub session and an isolated disk cache.
    init(session: URLSession,
         diskCache: any ImageDiskCacheContract,
         configuration: ImageLoaderConfiguration = .default,
         networkLogger: any APILogSinkContract = NoOpAPILogger(),
         cacheLogger: any CacheLogSinkContract = NoOpCacheLogger()) {
        self.session = session
        self.diskCache = diskCache
        self.memory = ImageMemoryCache(costLimit: configuration.memoryCostLimit)
        self.loggerBox = LoggerBox(network: networkLogger, cache: cacheLogger)
    }

    /// Points logging at the app's stores. Non-isolated so `AppContainer.init` can call it before any
    /// load; loggers default to no-ops, so an unconfigured loader logs nothing.
    public nonisolated func setLoggers(network: any APILogSinkContract,
                                       cache: any CacheLogSinkContract) {
        loggerBox.set(network: network, cache: cache)
    }

    /// The decoded image if already in memory, else `nil`. Synchronous — does not check disk (I/O on
    /// the main thread).
    /// - Parameter maxPixelSize: part of the cache key; must match the value passed to
    ///   ``image(for:maxPixelSize:)``.
    public nonisolated func cachedImage(for url: URL, maxPixelSize: CGFloat) -> UIImage? {
        memory[ImageKey(url: url, maxPixelSize: maxPixelSize)]
    }

    /// Fetches and downsamples the image if necessary. Cancelling the caller does not cancel an
    /// in-flight download — other rows may share it.
    public func image(for url: URL, maxPixelSize: CGFloat) async throws -> UIImage {
        let key = ImageKey(url: url, maxPixelSize: maxPixelSize)
        if let cached = memory[key] {
            log(.hit(layer: .memory, isExpired: false), for: url)
            return cached
        }

        let task = inFlightTask(for: key)
        // Clears on failure so the next caller retries instead of awaiting an already-thrown task.
        defer { inFlight[key] = nil }

        let image = try await task.value
        memory[key] = image
        return image
    }

    /// Drops decoded images; disk cache is untouched, so repopulating costs a decode, not a round trip.
    public nonisolated func clearMemoryCache() {
        memory.removeAll()
    }

    /// Drops all cached images on disk. See ``ImageDiskCacheContract/removeAll()``.
    public func clearDiskCache() async throws {
        try await diskCache.removeAll()
    }

    private func inFlightTask(for key: ImageKey) -> Task<UIImage, Error> {
        if let existing = inFlight[key] { return existing }

        let session = session
        let diskCache = diskCache
        let loggerBox = loggerBox
        // Detached: a plain `Task` would inherit actor isolation and serialize decodes.
        let task = Task.detached(priority: .utility) {
            let maxPixelSize = CGFloat(key.maxPixelSize)
            let url = key.url
            let (networkLogger, cacheLogger) = (loggerBox.loggers.network, loggerBox.loggers.cache)

            // A corrupt or unreadable disk entry falls through to the network rather than failing.
            if let stored = try? await diskCache.data(for: url),
               let image = try? ImageDownsampler.decode(stored, maxPixelSize: maxPixelSize) {
                cacheLogger.log(ImageLoader.cacheEvent(.hit(layer: .disk, isExpired: false), for: url))
                return image
            }
            cacheLogger.log(ImageLoader.cacheEvent(.miss, for: url))

            let request = URLRequest(url: url)
            let requestRecord = APIRequestRecord(
                kind: .image,
                method: "GET",
                url: url,
                headers: request.allHTTPHeaderFields ?? [:],
                body: nil
            )
            networkLogger.log(.request(requestRecord))
            let start = Date()

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch let error as URLError {
                // Logged before rethrow so the inspector still sees a closed entry.
                networkLogger.log(.response(APIResponseRecord(
                    id: requestRecord.id,
                    kind: .image,
                    method: "GET",
                    url: url,
                    outcome: .transportError(description: error.localizedDescription),
                    headers: [:],
                    body: nil,
                    duration: Date().timeIntervalSince(start)
                )))
                throw error
            }

            let http = response as? HTTPURLResponse
            let statusCode = http?.statusCode ?? 200
            networkLogger.log(.response(APIResponseRecord(
                id: requestRecord.id,
                kind: .image,
                method: "GET",
                url: url,
                outcome: (200..<300).contains(statusCode)
                    ? .success(statusCode: statusCode)
                    : .failure(statusCode: statusCode),
                headers: http?.allHeaderFields.reduce(into: [String: String]()) { headers, entry in
                    headers["\(entry.key)"] = "\(entry.value)"
                } ?? [:],
                body: data,
                duration: Date().timeIntervalSince(start)
            )))

            if !(200..<300).contains(statusCode) {
                throw ImageLoadingError.unacceptableStatusCode(statusCode)
            }
            // Best-effort: a failing disk write must not block returning the image.
            try? await diskCache.store(data, for: url)
            return try ImageDownsampler.decode(data, maxPixelSize: maxPixelSize)
        }

        inFlight[key] = task
        return task
    }

    private func log(_ outcome: CacheLogEvent.Outcome, for url: URL) {
        loggerBox.loggers.cache.log(Self.cacheEvent(outcome, for: url))
    }

    /// Keyed under the "images" namespace so inspector lines look like other cache lines.
    private static func cacheEvent(_ outcome: CacheLogEvent.Outcome, for url: URL) -> CacheLogEvent {
        CacheLogEvent(
            key: CacheKey(namespace: "images", identifier: url.absoluteString),
            outcome: outcome
        )
    }
}
