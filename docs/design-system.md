# Design system

The `DesignSystem` package currently holds the image pipeline. It depends on `Storage` (for the disk store) and `Networking` (for the log records).

## `CachedAsyncImage`

- A drop-in replacement for `AsyncImage` backed by `ImageLoader`. It takes a URL, a `maxPixelSize` (rendered size × display scale) and content and placeholder builders. Convenience initializers cover the default placeholder and a plain `Image` content.
- The memory cache is read synchronously in `init`, so a recycled row in a `List` or lazy stack draws immediately instead of resetting to a placeholder. That read is not logged; the `.task` that follows always goes through the loader, which answers from the same memory cache and logs one event per appearance.
- Every feature uses `ImageLoader.shared` so all screens pool one cache.

## `ImageLoader`

- An actor that checks memory, then disk, then network, and coalesces concurrent requests for the same image and size.
- Decoding goes through `ImageDownsampler`, which uses ImageIO to produce a bitmap no larger than `maxPixelSize` on its longest edge. The full-resolution bitmap is never materialized; a decoded image costs width × height × 4 bytes regardless of the frame it is drawn in.
- Sections decide the decode size once, not per cell. The memory cache is keyed on URL *and* size, so a per-cell measurement would fragment it into near-duplicate bitmaps. Full-width images (the characters grid, the detail header, the locations carousel) measure their width once with `onGeometryChange`; avatars use a fixed point size per row (56 in the characters list, 32 in the episodes list, 50 for location residents) multiplied by the `displayScale` read from the environment.
- The loader's session has no `URLCache`, so bytes are not stored twice under two eviction policies that cannot see each other.
- `setLoggers(network:cache:)` installs the app's log stores on the shared instance. It is synchronous and nonisolated behind a `Mutex` because the loader is a static that exists before the container, and launch traffic is exactly what the request inspector should show. Image downloads log as `APILogKind.image` through the same records as API calls.

## Two caches, two policies

- `ImageMemoryCache` is an `NSCache` of decoded, downsampled bitmaps with an advisory cost limit (64 MB by default).
- `ImageDiskCache` stores the **original encoded bytes** on `DiskStoreContract` under the `images` namespace. A 300×300 avatar is 10 to 30 KB compressed against 360 KB decoded.
- There is no expiry. Image URLs are immutable and there is nothing to revalidate, which is exactly the case `CacheStoreContract` is not for, so the image cache sits directly on the disk layer.
- A 128 MB cap is a safety net, not a working limit; the whole catalogue is around 16 MB. When it is exceeded, the namespace is trimmed oldest-first down to 75% of the cap, once per process on first use.
- `ImageLoaderConfiguration` exposes both limits. Tests build isolated loaders over fresh temp directories.

## Clearing

- `clearMemoryCache()` is synchronous; `clearDiskCache()` is async. The developer tools clear memory first and disk second, so visible avatars disappear and the button visibly did something.
