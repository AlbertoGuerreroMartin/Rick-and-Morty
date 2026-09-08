import Foundation
import Networking
import Storage
import Synchronization
import UIKit

public enum ImageLoadingError: Error, Equatable {
    /// The bytes came back fine but no image decoder recognised them.
    case undecodableData
    /// The server answered with a status outside 200..<300.
    case unacceptableStatusCode(Int)
}

/// Loads, downsamples, and caches remote images.
///
/// Three caches, in the order a request consults them:
///
/// 1. **Memory — decoded bitmaps.** `AsyncImage` keeps none, so every time a
///    recycled row scrolls back it re-decodes from scratch and shows a
///    placeholder while it does. Here the decoded bitmap is kept, and
///    ``cachedImage(for:maxPixelSize:)`` answers synchronously so the row can
///    draw on its first frame.
/// 2. **Disk — the original encoded bytes** (``ImageDiskCache``). Survives
///    relaunch, so a cold start costs a decode rather than a round trip.
/// 3. **The network**, once, even when ten rows ask at the same moment:
///    concurrent requests for the same image are coalesced.
///
/// Images are downsampled at decode time throughout, so a large source never
/// materialises as a full-resolution bitmap just to fill a small frame — and a
/// disk hit is decoded through exactly the same path as a fresh download, so the
/// two cannot drift apart.
///
/// Use ``shared`` unless you need an isolated cache — the whole benefit comes
/// from feature modules pooling one instance.
public actor ImageLoader {
    public static let shared = ImageLoader()

    /// Not isolated: `NSCache` is thread-safe on its own, and a synchronous
    /// main-thread read is exactly what makes first-frame rendering possible.
    private nonisolated let memory: ImageMemoryCache

    private let session: URLSession
    private let diskCache: any ImageDiskCacheContract
    private var inFlight: [ImageKey: Task<UIImage, Error>] = [:]

    /// The two sinks an image load writes to.
    ///
    /// Not actor state, because the app has to configure ``shared`` from
    /// `AppContainer.init` — synchronous, non-isolated code. Hopping onto the
    /// actor to install a logger would mean the first images could load before
    /// the loggers arrived, and the launch traffic is exactly what a developer
    /// opening the inspector wants to see. A `Mutex` around two references is
    /// read once per load and never contended.
    ///
    /// A class around the `Mutex` rather than the `Mutex` itself: `Mutex` is
    /// non-copyable, and the detached download task needs to capture the thing
    /// it reads the sinks from.

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
        // No `URLCache` at all, and a policy that ignores it. `ImageDiskCache`
        // already holds the encoded bytes; leaving URLCache on would store a
        // second copy of every image, doubling the disk cost for nothing and
        // splitting the eviction policy across two layers that cannot see each
        // other.
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

    /// Injecting initializer, for tests that stub the network and want a disk
    /// cache of their own rather than the shared one under `Library/Caches`.
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

    /// Points this loader's logging at the app's stores.
    ///
    /// Synchronous and non-isolated so the composition root can call it on
    /// ``shared`` during `init`, before any view has had a chance to ask for an
    /// image. Loggers default to no-ops, so a loader nobody configures — a
    /// preview, a test — logs nothing rather than crashing or printing.
    public nonisolated func setLoggers(network: any APILogSinkContract,
                                       cache: any CacheLogSinkContract) {
        loggerBox.set(network: network, cache: cache)
    }

    /// The decoded image if it is already in memory, or `nil`.
    ///
    /// Cheap and synchronous by design — call it from `View.init` to decide
    /// whether a placeholder is needed at all. It deliberately does *not* look
    /// at the disk: that would be I/O on the main thread.
    ///
    /// - Parameter maxPixelSize: longest-edge size, **in pixels**, that the
    ///   image was requested at. It is part of the cache identity, so it has to
    ///   match the value passed to ``image(for:maxPixelSize:)``.
    public nonisolated func cachedImage(for url: URL, maxPixelSize: CGFloat) -> UIImage? {
        memory[ImageKey(url: url, maxPixelSize: maxPixelSize)]
    }

    /// The decoded image, fetching and downsampling it if necessary.
    ///
    /// Cancelling the calling task does **not** cancel an in-flight download:
    /// other rows may be waiting on the same one, and letting it finish warms
    /// the cache for the next time the row scrolls into view.
    public func image(for url: URL, maxPixelSize: CGFloat) async throws -> UIImage {
        let key = ImageKey(url: url, maxPixelSize: maxPixelSize)
        if let cached = memory[key] {
            log(.hit(layer: .memory, isExpired: false), for: url)
            return cached
        }

        let task = inFlightTask(for: key)
        // Runs once this call resumes, i.e. after the shared task has finished.
        // Clearing on failure is deliberate: the next caller should retry
        // rather than await a task that already threw.
        defer { inFlight[key] = nil }

        let image = try await task.value
        memory[key] = image
        return image
    }

    /// Drops every decoded image. The disk layer is untouched, so repopulating
    /// it costs a decode rather than a round trip.
    public nonisolated func clearMemoryCache() {
        memory.removeAll()
    }

    /// Drops every image on disk, so the next request for any of them goes to
    /// the network. See ``ImageDiskCacheContract/removeAll()`` for why this
    /// exists at all when nothing here expires.
    public func clearDiskCache() async throws {
        try await diskCache.removeAll()
    }

    private func inFlightTask(for key: ImageKey) -> Task<UIImage, Error> {
        if let existing = inFlight[key] { return existing }

        let session = session
        let diskCache = diskCache
        let loggerBox = loggerBox
        // Detached on purpose: a plain `Task` would inherit this actor's
        // isolation and run the synchronous decode on the actor's executor,
        // serialising every decode behind the loader.
        let task = Task.detached(priority: .utility) {
            let maxPixelSize = CGFloat(key.maxPixelSize)
            let url = key.url
            let (networkLogger, cacheLogger) = (loggerBox.loggers.network, loggerBox.loggers.cache)

            // A disk entry that cannot be read *or* cannot be decoded falls
            // through to the network rather than failing the request: a corrupt
            // or truncated file must cost a download, not a broken image.
            if let stored = try? await diskCache.data(for: url),
               let image = try? ImageDownsampler.decode(stored, maxPixelSize: maxPixelSize) {
                cacheLogger.log(ImageLoader.cacheEvent(.hit(layer: .disk, isExpired: false), for: url))
                return image
            }
            // An unreadable file is logged as a miss rather than as its own
            // outcome: what the caller got is nothing either way, and the line
            // that follows — a request for the same URL — says the rest.
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
                // Logged before rethrowing, so a download that never produced a
                // response still closes its pending entry in the inspector.
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
            // Written before the decode, and best-effort: a failing disk should
            // slow the app down, never stop it from showing an image it holds.
            try? await diskCache.store(data, for: url)
            return try ImageDownsampler.decode(data, maxPixelSize: maxPixelSize)
        }

        inFlight[key] = task
        return task
    }

    private func log(_ outcome: CacheLogEvent.Outcome, for url: URL) {
        loggerBox.loggers.cache.log(Self.cacheEvent(outcome, for: url))
    }

    /// The image caches are keyed by URL under the same "images" namespace the
    /// disk store uses, so an image line in the inspector reads exactly like a
    /// characters or episodes line and needs no special case to render.
    private static func cacheEvent(_ outcome: CacheLogEvent.Outcome, for url: URL) -> CacheLogEvent {
        CacheLogEvent(
            key: CacheKey(namespace: "images", identifier: url.absoluteString),
            outcome: outcome
        )
    }
}
