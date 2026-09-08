import Foundation
import Synchronization

/// Intercepts requests made by a `URLSession` configured with it, so the image
/// tests never touch the network and can count exactly how many requests a URL
/// received — which is how request coalescing gets verified.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub: Sendable {
        var statusCode: Int = 200
        var data: Data
        /// Seconds to hold the response, so a test can keep a request in flight.
        var delay: TimeInterval = 0
    }

    private struct State: Sendable {
        var stubs: [URL: Stub] = [:]
        var requestCounts: [URL: Int] = [:]
    }

    private static let state = Mutex(State())

    static func stub(_ url: URL, with stub: Stub) {
        state.withLock { $0.stubs[url] = stub }
    }

    static func requestCount(for url: URL) -> Int {
        state.withLock { $0.requestCounts[url] ?? 0 }
    }

    /// Records the hit and returns the stub in one atomic step.
    private static func recordRequest(for url: URL) -> Stub? {
        state.withLock { state in
            state.requestCounts[url, default: 0] += 1
            return state.stubs[url]
        }
    }

    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let stub = Self.recordRequest(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        guard stub.delay > 0 else {
            respond(with: stub, url: url)
            return
        }
        // GCD rather than a Task: `Task.init` takes a `sending` closure, which
        // this URLProtocol instance cannot satisfy.
        DispatchQueue.global().asyncAfter(deadline: .now() + stub.delay) { [self] in
            respond(with: stub, url: url)
        }
    }

    override func stopLoading() {}

    private func respond(with stub: Stub, url: URL) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
