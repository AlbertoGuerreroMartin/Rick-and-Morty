import Foundation

/// Tuning knobs for ``ImageLoader``.
///
/// Two caches sit behind an image request and they hold different things:
/// `memoryCostLimit` bounds *decoded* images (already downsampled bitmaps, the
/// expensive thing to recreate), while the `urlCache*` capacities bound the
/// *encoded* bytes so a cold launch can skip the network entirely.
public struct ImageLoaderConfiguration: Sendable {
    /// Approximate ceiling, in bytes, for decoded images held in memory.
    ///
    /// `NSCache` treats this as advisory and evicts under memory pressure well
    /// before the limit is reached, so it is a budget rather than a guarantee.
    public var memoryCostLimit: Int

    /// In-memory capacity, in bytes, of the loader's private `URLCache`.
    public var urlCacheMemoryCapacity: Int

    /// On-disk capacity, in bytes, of the loader's private `URLCache`.
    public var urlCacheDiskCapacity: Int

    /// Cache policy applied to every image request.
    ///
    /// Defaults to ``URLRequest/CachePolicy/returnCacheDataElseLoad`` because
    /// image URLs are normally immutable — a given URL keeps serving the same
    /// bytes forever — which makes revalidation pure latency. Switch to
    /// `.useProtocolCachePolicy` if your image URLs are ever reused for new
    /// content and you need `Cache-Control` to be honoured.
    public var requestCachePolicy: URLRequest.CachePolicy

    public init(
        memoryCostLimit: Int = 64 * 1_024 * 1_024,
        urlCacheMemoryCapacity: Int = 32 * 1_024 * 1_024,
        urlCacheDiskCapacity: Int = 256 * 1_024 * 1_024,
        requestCachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad
    ) {
        self.memoryCostLimit = memoryCostLimit
        self.urlCacheMemoryCapacity = urlCacheMemoryCapacity
        self.urlCacheDiskCapacity = urlCacheDiskCapacity
        self.requestCachePolicy = requestCachePolicy
    }

    public static let `default` = ImageLoaderConfiguration()
}
