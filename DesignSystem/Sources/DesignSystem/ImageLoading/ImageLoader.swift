import Foundation
import UIKit

public enum ImageLoadingError: Error, Equatable {
    /// The bytes came back fine but no image decoder recognised them.
    case undecodableData
    /// The server answered with a status outside 200..<300.
    case unacceptableStatusCode(Int)
}

/// Loads, downsamples, and caches remote images.
///
/// Three things separate this from `AsyncImage`, and all three matter in a list
/// that renders one image per row:
///
/// 1. **Decoded images are cached.** `AsyncImage` leans on `URLCache`, which
///    stores compressed *bytes*; every time a recycled row scrolls back it
///    re-decodes from scratch and shows a placeholder while it does. Here the
///    decoded bitmap is kept, and ``cachedImage(for:maxPixelSize:)`` answers
///    synchronously so the row can draw on its first frame.
/// 2. **Concurrent requests for the same image are coalesced.** Ten rows
///    showing the same avatar produce one download, not ten.
/// 3. **Images are downsampled at decode time**, so a large source never
///    materialises as a full-resolution bitmap just to fill a small frame.
///
/// Use ``shared`` unless you need an isolated cache — the whole benefit comes
/// from feature modules pooling one instance.
public actor ImageLoader {
    public static let shared = ImageLoader()

    /// Not isolated: `NSCache` is thread-safe on its own, and a synchronous
    /// main-thread read is exactly what makes first-frame rendering possible.
    private nonisolated let memory: ImageMemoryCache

    private let session: URLSession
    private let cachePolicy: URLRequest.CachePolicy
    private var inFlight: [ImageKey: Task<UIImage, Error>] = [:]

    public init(configuration: ImageLoaderConfiguration = .default) {
        let sessionConfiguration = URLSessionConfiguration.default
        // A private URLCache rather than URLCache.shared: the shared one is far
        // too small for images by default, and resizing it would change caching
        // behaviour for every other request the app makes.
        sessionConfiguration.urlCache = URLCache(
            memoryCapacity: configuration.urlCacheMemoryCapacity,
            diskCapacity: configuration.urlCacheDiskCapacity,
            directory: nil
        )
        sessionConfiguration.requestCachePolicy = configuration.requestCachePolicy
        self.init(
            session: URLSession(configuration: sessionConfiguration),
            configuration: configuration
        )
    }

    /// Session-injecting initializer, for tests that stub the network.
    init(session: URLSession, configuration: ImageLoaderConfiguration = .default) {
        self.session = session
        self.cachePolicy = configuration.requestCachePolicy
        self.memory = ImageMemoryCache(costLimit: configuration.memoryCostLimit)
    }

    /// The decoded image if it is already in memory, or `nil`.
    ///
    /// Cheap and synchronous by design — call it from `View.init` to decide
    /// whether a placeholder is needed at all.
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

    /// Drops every decoded image. The `URLCache` layer is untouched, so
    /// repopulating it costs a decode rather than a round trip.
    public nonisolated func clearMemoryCache() {
        memory.removeAll()
    }

    private func inFlightTask(for key: ImageKey) -> Task<UIImage, Error> {
        if let existing = inFlight[key] { return existing }

        let session = session
        let cachePolicy = cachePolicy
        // Detached on purpose: a plain `Task` would inherit this actor's
        // isolation and run the synchronous decode on the actor's executor,
        // serialising every decode behind the loader.
        let task = Task.detached(priority: .utility) {
            var request = URLRequest(url: key.url)
            request.cachePolicy = cachePolicy

            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw ImageLoadingError.unacceptableStatusCode(http.statusCode)
            }
            return try ImageDownsampler.decode(data, maxPixelSize: CGFloat(key.maxPixelSize))
        }

        inFlight[key] = task
        return task
    }
}
