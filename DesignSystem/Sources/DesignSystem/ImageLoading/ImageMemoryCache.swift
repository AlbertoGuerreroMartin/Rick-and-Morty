import Foundation
import UIKit

/// Thread-safe store of decoded, downsampled images keyed by URL and target size.
///
/// This deliberately lives *outside* ``ImageLoader``'s actor isolation. A cache
/// read has to be answerable synchronously from the main thread: that is what
/// lets ``CachedAsyncImage`` render an already-loaded image on its very first
/// frame instead of flashing a placeholder every time a recycled row scrolls
/// back into view. `NSCache` is documented as thread-safe, so the unchecked
/// conformance is honest rather than a papering-over.
final class ImageMemoryCache: @unchecked Sendable {
    private let storage = NSCache<NSString, UIImage>()

    init(costLimit: Int) {
        storage.totalCostLimit = costLimit
    }

    subscript(key: ImageKey) -> UIImage? {
        get { storage.object(forKey: key.storageKey) }
        set {
            guard let newValue else {
                storage.removeObject(forKey: key.storageKey)
                return
            }
            storage.setObject(newValue, forKey: key.storageKey, cost: newValue.decodedByteCount)
        }
    }

    func removeAll() {
        storage.removeAllObjects()
    }
}

/// Identifies a decoded image. The pixel size is part of the identity because
/// the same URL downsampled for a 64pt avatar and for a full-width header are
/// two different bitmaps, and returning one where the other was asked for would
/// silently ship a blurry or oversized image.
struct ImageKey: Hashable, Sendable {
    let url: URL
    let maxPixelSize: Int

    init(url: URL, maxPixelSize: CGFloat) {
        self.url = url
        self.maxPixelSize = Int(maxPixelSize.rounded())
    }

    var storageKey: NSString {
        "\(maxPixelSize)|\(url.absoluteString)" as NSString
    }
}

private extension UIImage {
    /// Bytes the bitmap actually occupies, which is what the cache should be
    /// budgeting — not the size of the compressed file it came from.
    var decodedByteCount: Int {
        guard let cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
