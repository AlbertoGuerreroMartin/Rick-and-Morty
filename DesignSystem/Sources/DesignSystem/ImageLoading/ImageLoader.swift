import Foundation
import Storage
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
         configuration: ImageLoaderConfiguration = .default) {
        self.session = session
        self.diskCache = diskCache
        self.memory = ImageMemoryCache(costLimit: configuration.memoryCostLimit)
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
        if let cached = memory[key] { return cached }

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

    private func inFlightTask(for key: ImageKey) -> Task<UIImage, Error> {
        if let existing = inFlight[key] { return existing }

        let session = session
        let diskCache = diskCache
        // Detached on purpose: a plain `Task` would inherit this actor's
        // isolation and run the synchronous decode on the actor's executor,
        // serialising every decode behind the loader.
        let task = Task.detached(priority: .utility) {
            let maxPixelSize = CGFloat(key.maxPixelSize)

            // A disk entry that cannot be read *or* cannot be decoded falls
            // through to the network rather than failing the request: a corrupt
            // or truncated file must cost a download, not a broken image.
            if let stored = try? await diskCache.data(for: key.url),
               let image = try? ImageDownsampler.decode(stored, maxPixelSize: maxPixelSize) {
                return image
            }

            let (data, response) = try await session.data(for: URLRequest(url: key.url))
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw ImageLoadingError.unacceptableStatusCode(http.statusCode)
            }
            // Written before the decode, and best-effort: a failing disk should
            // slow the app down, never stop it from showing an image it holds.
            try? await diskCache.store(data, for: key.url)
            return try ImageDownsampler.decode(data, maxPixelSize: maxPixelSize)
        }

        inFlight[key] = task
        return task
    }
}
