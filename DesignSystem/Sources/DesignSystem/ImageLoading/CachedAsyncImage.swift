import SwiftUI

/// Drop-in replacement for `AsyncImage` backed by ``ImageLoader``.
///
/// The difference that matters in a `List` or `LazyVStack`: this view asks the
/// memory cache for the image in its *initializer*, so a row scrolling back
/// into view draws its image immediately instead of resetting to a placeholder
/// and re-decoding — which is what `AsyncImage` does every time SwiftUI
/// recreates a recycled row.
///
/// The read in the initializer is deliberately not logged as a cache hit: it is
/// the same load as the `.task` that follows a moment later, and counting it
/// would double every hit in the inspector for no new information. The `.task`
/// always goes through ``ImageLoader/image(for:maxPixelSize:)``, so one
/// appearance is one event.
public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let maxPixelSize: CGFloat
    private let loader: ImageLoader
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var image: Image?

    /// - Parameters:
    ///   - url: image to load; `nil` renders the placeholder.
    ///   - maxPixelSize: longest edge, **in pixels**, to decode at. Pass the
    ///     rendered size multiplied by the display scale — a 64pt avatar on a
    ///     3x screen wants roughly 192. Oversizing wastes memory; undersizing
    ///     looks soft.
    ///   - loader: defaults to ``ImageLoader/shared`` so every feature module
    ///     pools one cache.
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

        // Re-check the cache here as well as in `init`: SwiftUI reuses a view's
        // `@State` when only the URL changes, so `image` may still hold the
        // previous row's picture. A hit adopts it immediately, which is what
        // keeps a recycled row from flashing a placeholder — but it does *not*
        // return: the load below answers from the same memory cache without
        // touching the disk or the network, and going through it is what makes
        // every appearance produce exactly one cache event. Returning early
        // here would leave the busiest path in the app — a scroll over rows
        // that are already cached — invisible in the inspector, which is the
        // one place someone looks to find out why an image did not appear.
        if let cached = loader.cachedImage(for: url, maxPixelSize: maxPixelSize) {
            image = Image(uiImage: cached)
        } else {
            image = nil
        }

        guard let loaded = try? await loader.image(for: url, maxPixelSize: maxPixelSize) else { return }
        // The load outlives cancellation on purpose (see `ImageLoader.image`),
        // so check before touching state that may belong to a recycled row.
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

/// Neutral fill shown while an image loads, or when it fails to.
///
/// Deliberately inert: a spinner per row reads as chaos while scrolling, and a
/// shimmer animating on twenty offscreen cells is wasted work.
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
