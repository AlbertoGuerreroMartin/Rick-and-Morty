import Foundation
import ImageIO
import UIKit

/// Decodes image data straight into a bitmap no larger than `maxPixelSize` on its longest edge,
/// so the full-resolution bitmap is never materialized (a decoded image costs
/// `width * height * 4` bytes regardless of the frame it's drawn in).
enum ImageDownsampler {
    static func decode(_ data: Data, maxPixelSize: CGFloat) throws -> UIImage {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            throw ImageLoadingError.undecodableData
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Honours EXIF orientation while resizing, so the result can be treated as `.up`.
            kCGImageSourceCreateThumbnailWithTransform: true,
            // Forces the decode onto this (background) thread rather than lazily at draw time.
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize.rounded())
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            throw ImageLoadingError.undecodableData
        }

        // Scale 1: `UIImage.size` is reported in pixels; unresized drawing should size explicitly.
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}
