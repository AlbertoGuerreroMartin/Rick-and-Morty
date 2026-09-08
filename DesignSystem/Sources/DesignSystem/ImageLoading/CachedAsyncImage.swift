import SwiftUI

/// Drop-in replacement for `AsyncImage` backed by ``ImageLoader``. Checks the memory cache in
/// `init` too, so a recycled row in a `List`/`LazyVStack` draws immediately instead of resetting
/// to a placeholder. That initializer read is not logged as a hit — the `.task` that follows logs
/// the same load, so counting both would double every hit in the inspector.
public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let maxPixelSize: CGFloat
    private let loader: ImageLoader
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var image: Image?

    /// - Parameters:
    ///   - url: image to load; `nil` renders the placeholder.
    ///   - maxPixelSize: longest edge in pixels to decode at (rendered size × display scale).
    ///   - loader: defaults to ``ImageLoader/shared`` so every feature module pools one cache.
    public init(
        url: URL?,
        maxPixelSize: CGFloat,
        loader: ImageLoader = .shared,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.loader = loader
        self.content = content
        self.placeholder = placeholder
        _image = State(
            initialValue: url
                .flatMap { loader.cachedImage(for: $0, maxPixelSize: maxPixelSize) }
                .map(Image.init(uiImage:))
        )
    }

    public var body: some View {
        Group {
            if let image {
                content(image)
            } else {
                placeholder()
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            image = nil
            return
        }

        // Re-checked here too (not just `init`): SwiftUI reuses `@State` across URL changes, so
        // a hit adopts it immediately without returning early — the load below still runs so
        // every appearance produces one cache event, keeping cached rows visible in the inspector.
        if let cached = loader.cachedImage(for: url, maxPixelSize: maxPixelSize) {
            image = Image(uiImage: cached)
        } else {
            image = nil
        }

        guard let loaded = try? await loader.image(for: url, maxPixelSize: maxPixelSize) else { return }
        // Load outlives cancellation (see `ImageLoader.image`); check before touching state
        // that may belong to a recycled row.
        guard !Task.isCancelled else { return }
        image = Image(uiImage: loaded)
    }
}

public extension CachedAsyncImage where Placeholder == ImagePlaceholder {
    init(
        url: URL?,
        maxPixelSize: CGFloat,
        loader: ImageLoader = .shared,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(
            url: url,
            maxPixelSize: maxPixelSize,
            loader: loader,
            content: content,
            placeholder: { ImagePlaceholder() }
        )
    }
}

public extension CachedAsyncImage where Content == Image, Placeholder == ImagePlaceholder {
    /// Resizable image with the default placeholder. Apply `.scaledToFill()`,
    /// `.frame(...)`, and clipping at the call site.
    init(url: URL?, maxPixelSize: CGFloat, loader: ImageLoader = .shared) {
        self.init(
            url: url,
            maxPixelSize: maxPixelSize,
            loader: loader,
            content: { $0.resizable() },
            placeholder: { ImagePlaceholder() }
        )
    }
}

/// Neutral fill shown while loading or on failure. Deliberately inert — a spinner or shimmer
/// per row is wasted work while scrolling.
public struct ImagePlaceholder: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(.quaternary)
    }
}

#Preview {
    let avatar = URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")

    return List(0..<20) { index in
        HStack(spacing: 12) {
            CachedAsyncImage(url: avatar, maxPixelSize: 192)
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 8))
            Text("Row \(index)")
        }
    }
}
