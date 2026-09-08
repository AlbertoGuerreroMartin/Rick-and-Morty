import Foundation
import ImageIO
import UIKit

/// Decodes image data straight into a bitmap no larger than `maxPixelSize` on
/// its longest edge.
///
/// The point is to never materialise the full-resolution bitmap at all. A
/// decoded image costs `width * height * 4` bytes regardless of the frame it is
/// drawn in, so a 2000x2000 source is 16 MB even when it lands in a 64pt row.
/// `CGImageSourceCreateThumbnailAtIndex` reads the source's dimensions from its
/// header and decodes directly at the requested size.
enum ImageDownsampler {
    static func decode(_ data: Data, maxPixelSize: CGFloat) throws -> UIImage {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            throw ImageLoadingError.undecodableData
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Honour EXIF orientation while resizing, so the result needs no
            // further correction and can be treated as `.up`.
            kCGImageSourceCreateThumbnailWithTransform: true,
            // Force the decode to happen here, on whatever background thread
            // called us, rather than lazily on the main thread at draw time.
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize.rounded())
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            throw ImageLoadingError.undecodableData
        }

        // Scale 1 means `UIImage.size` is reported in pixels. Every call site in
        // this module renders with `.resizable()`, where the intrinsic size is
        // irrelevant; anything drawing it unresized should size it explicitly.
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}
