import Foundation
import UIKit

/// Thread-safe store of decoded, downsampled images keyed by URL and target size. Lives outside
/// ``ImageLoader``'s actor isolation so a read is answerable synchronously from the main thread,
/// letting ``CachedAsyncImage`` render on its first frame. `NSCache` is documented thread-safe,
/// so the unchecked conformance is honest.
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

/// Identifies a decoded image. Pixel size is part of the identity: the same URL downsampled
/// for an avatar vs. a full-width header are different bitmaps.
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
    /// Bytes the bitmap occupies — not the compressed file size it came from.
    var decodedByteCount: Int {
        guard let cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
