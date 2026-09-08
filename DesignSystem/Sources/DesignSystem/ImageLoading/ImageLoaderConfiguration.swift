import Foundation

/// Tuning knobs for ``ImageLoader``: `memoryCostLimit` bounds decoded bitmaps, `diskCapacity`
/// bounds the encoded bytes kept by ``ImageDiskCache``.
public struct ImageLoaderConfiguration: Sendable {
    /// Approximate ceiling, in bytes, for decoded images in memory. `NSCache` treats this as
    /// advisory and may evict earlier under memory pressure.
    public var memoryCostLimit: Int

    /// Ceiling, in bytes, for encoded image bytes on disk. A safety net, not a working limit —
    /// see ``ImageDiskCache``. Entries are evicted by size only; image URLs never go stale.
    public var diskCapacity: Int

    public init(
        memoryCostLimit: Int = 64 * 1_024 * 1_024,
        diskCapacity: Int = 128 * 1_024 * 1_024
    ) {
        self.memoryCostLimit = memoryCostLimit
        self.diskCapacity = diskCapacity
    }

    public static let `default` = ImageLoaderConfiguration()
}
