import Foundation

/// Tuning knobs for ``ImageLoader``.
///
/// Two caches sit behind an image request and they hold different things:
/// `memoryCostLimit` bounds *decoded* images (already downsampled bitmaps, the
/// expensive thing to recreate), while `diskCapacity` bounds the *encoded* bytes
/// kept by ``ImageDiskCache`` so a cold launch can skip the network entirely.
public struct ImageLoaderConfiguration: Sendable {
    /// Approximate ceiling, in bytes, for decoded images held in memory.
    ///
    /// `NSCache` treats this as advisory and evicts under memory pressure well
    /// before the limit is reached, so it is a budget rather than a guarantee.
    public var memoryCostLimit: Int

    /// Ceiling, in bytes, for encoded image bytes on disk.
    ///
    /// A safety net rather than a working limit — see ``ImageDiskCache``. There
    /// is no expiry to pair it with: image URLs are immutable, so an entry is
    /// only ever evicted because of size, never because of age.
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
