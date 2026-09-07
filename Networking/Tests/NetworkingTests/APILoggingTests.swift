//
//  APILoggingTests.swift
//  Networking
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation
import Testing
@testable import Networking

// MARK: - Formatter

/// The console format is a contract with whoever reads the Xcode console, so
/// it is asserted line by line rather than "contains the URL".
@Suite("APILogFormatter")
struct APILogFormatterTests {
    private let formatter = APILogFormatter(timeZone: TimeZone(identifier: "UTC")!)
    private let url = URL(string: "https://rickandmortyapi.com/graphql")!
    /// 14:20:37.360 UTC on 2026-09-04.
    private let timestamp = Date(timeIntervalSince1970: 1_788_531_637.360)
    private let id = UUID()

    @Test("a request prints its line, method, sorted headers and a readable GraphQL body")
    func request() {
        let record = APIRequestRecord(
            id: id,
            timestamp: timestamp,
            method: "POST",
            url: url,
            headers: ["Content-Type": "application/json", "Accept": "application/json"],
            body: Data(#"{"query":"query($page: Int) {\n  result: characters(page: $page) {\n    id\n  }\n}","variables":{"page":1,"name":"Rick"}}"#.utf8)
        )

        #expect(formatter.string(for: record) == """
        ♦️ 14:20:37.360 > [PENDING] API Request: [POST] https://rickandmortyapi.com/graphql
        [Method]: POST
        [Headers]: \n\
            Accept: application/json
            Content-Type: application/json
        [Body]: \n\
            query: \n\
                query($page: Int) {
                  result: characters(page: $page) {
                    id
                  }
                }
            variables: \n\
                {
                  "name" : "Rick",
                  "page" : 1
                }
        """)
    }

    @Test("a request body that is not a GraphQL document is printed raw")
    func nonGraphQLRequestBody() {
        let record = APIRequestRecord(
            id: id, timestamp: timestamp, method: "POST", url: url, headers: [:],
            body: Data(#"{"hello":"world"}"#.utf8)
        )

        #expect(formatter.string(for: record).hasSuffix(#"[Body]: {"hello":"world"}"#))
    }

    @Test("a 2xx response prints as a success with its status code")
    func successResponse() {
        let body = Data(#"{"data":{}}"#.utf8)
        let record = APIResponseRecord(
            id: id,
            timestamp: timestamp,
            method: "POST",
            url: url,
            outcome: .success(statusCode: 200),
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: body,
            duration: 0.2
        )

        #expect(formatter.string(for: record) == """
        ♦️ 14:20:37.360 > [Done] API Request: [POST] https://rickandmortyapi.com/graphql
        [Response]: Success ✅
        Status Code: 200
        [Headers]: \n\
            Content-Type: application/json; charset=utf-8
        Response Length: \(body.count)
        Response body: {"data":{}}
        """)
    }

    @Test("a non-2xx response prints as a failure with its status code")
    func failureResponse() {
        let record = APIResponseRecord(
            id: id,
            timestamp: timestamp,
            method: "POST",
            url: url,
            outcome: .failure(statusCode: 429),
            headers: [:],
            body: nil,
            duration: 0.2
        )

        #expect(formatter.string(for: record) == """
        ♦️ 14:20:37.360 > [Done] API Request: [POST] https://rickandmortyapi.com/graphql
        [Response]: Failure ❌
        Status Code: 429
        [Headers]: \n\
        Response Length: 0
        Response body: <empty>
        """)
    }

    @Test("a transport error prints the error instead of a status code")
    func transportError() {
        let record = APIResponseRecord(
            id: id,
            timestamp: timestamp,
            method: "POST",
            url: url,
            outcome: .transportError(description: "The Internet connection appears to be offline."),
            headers: [:],
            body: nil,
            duration: 0.2
        )

        let lines = formatter.string(for: record).components(separatedBy: "\n")
        #expect(lines[1] == "[Response]: Failure ❌")
        #expect(lines[2] == "Error: The Internet connection appears to be offline.")
        #expect(!lines.contains { $0.hasPrefix("Status Code") })
    }

    @Test("a body that is not UTF-8 is described rather than dumped")
    func nonUTF8Body() {
        let record = APIRequestRecord(
            id: id, timestamp: timestamp, method: "POST", url: url, headers: [:],
            body: Data([0xFF, 0xFE, 0xFD])
        )

        #expect(formatter.string(for: record).hasSuffix("[Body]: <3 bytes of non-UTF-8 data>"))
    }

    /// The header line is what a console filter matches on, so "Image Request"
    /// is the whole point of the kind — an image download that still announced
    /// itself as "API Request" would be indistinguishable from a GraphQL call.
    @Test("an image request announces itself as an image")
    func imageRequestHeader() {
        let record = APIRequestRecord(
            id: id,
            timestamp: timestamp,
            kind: .image,
            method: "GET",
            url: URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")!,
            headers: [:],
            body: nil
        )

        #expect(formatter.string(for: record).hasPrefix(
            "♦️ 14:20:37.360 > [PENDING] Image Request: [GET] https://rickandmortyapi.com/api/character/avatar/1.jpeg"
        ))
    }

    @Test("an image response announces itself as an image")
    func imageResponseHeader() {
        let record = APIResponseRecord(
            id: id,
            timestamp: timestamp,
            kind: .image,
            method: "GET",
            url: URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")!,
            outcome: .success(statusCode: 200),
            headers: [:],
            body: Data([0xFF, 0xD8, 0xFF]),
            duration: 0.1
        )

        let lines = formatter.string(for: record).split(separator: "\n")
        #expect(lines.first == "♦️ 14:20:37.360 > [Done] Image Request: [GET] https://rickandmortyapi.com/api/character/avatar/1.jpeg")
        // Image bytes are described rather than dumped — the existing body
        // handling, which is exactly why images needed no new formatter.
        #expect(lines.last == "Response body: <3 bytes of non-UTF-8 data>")
    }

    /// The kind is defaulted so the GraphQL client never names it; if that
    /// default ever flipped, every API log would silently read "Image Request".
    @Test("a record left unqualified is an API record")
    func defaultKindIsAPI() {
        let request = APIRequestRecord(method: "POST", url: url, headers: [:], body: nil)
        let response = APIResponseRecord(id: request.id, method: "POST", url: url,
                                         outcome: .success(statusCode: 200), headers: [:],
                                         body: nil, duration: 0)

        #expect(request.kind == .api)
        #expect(response.kind == .api)
    }
}

// MARK: - Store

@Suite("APILogStore")
struct APILogStoreTests {
    private let url = URL(string: "https://rickandmortyapi.com/graphql")!

    private func makeRequest() -> APIRequestRecord {
        APIRequestRecord(method: "POST", url: url, headers: [:], body: nil)
    }

    private func makeResponse(for request: APIRequestRecord) -> APIResponseRecord {
        APIResponseRecord(id: request.id, method: "POST", url: url,
                          outcome: .success(statusCode: 200), headers: [:], body: nil, duration: 0)
    }

    @Test("keeps every event in the order it was logged")
    func keepsHistory() {
        let store = APILogStore()
        let request = makeRequest()
        let response = makeResponse(for: request)

        store.log(.request(request))
        store.log(.response(response))

        #expect(store.events == [.request(request), .response(response)])
    }

    @Test("forwards each event to every sink, the initial ones and the added ones")
    func fansOutToSinks() {
        let initial = SpySink()
        let added = SpySink()
        let store = APILogStore(sinks: [initial])
        store.add(added)
        let request = makeRequest()

        store.log(.request(request))

        #expect(initial.events == [.request(request)])
        #expect(added.events == [.request(request)])
    }

    @Test("a stream delivers events logged after subscribing, in order")
    func streamsLiveEvents() async {
        let store = APILogStore()
        let stream = store.stream()
        let request = makeRequest()
        let response = makeResponse(for: request)

        store.log(.request(request))
        store.log(.response(response))

        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == .request(request))
        #expect(await iterator.next() == .response(response))
    }

    @Test("removeAll drops the history but not the sinks")
    func removeAllKeepsSinks() {
        let sink = SpySink()
        let store = APILogStore(sinks: [sink])
        let first = makeRequest()
        let second = makeRequest()

        store.log(.request(first))
        store.removeAll()
        store.log(.request(second))

        #expect(store.events == [.request(second)])
        #expect(sink.events == [.request(first), .request(second)])
    }

    /// Images log through this store too, so the history has to stay bounded or
    /// a long scroll grows it until the app is killed.
    @Test("the history drops the oldest events past its capacity")
    func capsTheHistory() {
        let store = APILogStore(capacity: 3)
        let requests = (0..<5).map { _ in makeRequest() }

        for request in requests {
            store.log(.request(request))
        }

        #expect(store.events.map(\.id) == requests.suffix(3).map(\.id))
    }

    /// The cap is on the history alone: a sink and a live consumer have already
    /// been handed every event, and losing one there would be a dropped log
    /// rather than a trimmed one.
    @Test("the capacity does not affect sinks")
    func capDoesNotAffectSinks() {
        let sink = SpySink()
        let store = APILogStore(sinks: [sink], capacity: 1)

        for _ in 0..<4 {
            store.log(.request(makeRequest()))
        }

        #expect(store.events.count == 1)
        #expect(sink.events.count == 4)
    }
}

// MARK: - Client

/// The client must produce a request event before it hits the network and a
/// response event as soon as bytes arrive — regardless of whether it then
/// decides the call failed.
///
/// Serialized because `StubURLProtocol` is configured through a static, and a
/// `URLProtocol` subclass has no other channel to the test that registered it.
@Suite("GraphQLClient logging", .serialized)
struct GraphQLClientLoggingTests {
    private let endpoint = URL(string: "https://rickandmortyapi.com/graphql")!

    private func makeClient(logger: any APILogSinkContract) -> GraphQLClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return GraphQLClient(endpoint: endpoint, session: URLSession(configuration: configuration), logger: logger)
    }

    @Test("a successful call logs a request and a matching success response")
    func successfulCall() async throws {
        let body = Data(#"{"data":{"result":{"id":"1"}}}"#.utf8)
        StubURLProtocol.stub = .response(statusCode: 200, headers: ["X-Test": "yes"], body: body)
        let sink = SpySink()

        _ = try await makeClient(logger: sink).execute(LoggingTestQuery(id: "1"))

        #expect(sink.events.count == 2)
        guard case .request(let request) = sink.events[0],
              case .response(let response) = sink.events[1] else {
            Issue.record("expected a request followed by a response, got \(sink.events)")
            return
        }
        #expect(request.method == "POST")
        #expect(request.url == endpoint)
        #expect(request.headers["Content-Type"] == "application/json")
        #expect(request.body.map { String(decoding: $0, as: UTF8.self) }?.contains("\"variables\"") == true)
        #expect(response.id == request.id)
        #expect(response.outcome == .success(statusCode: 200))
        #expect(response.headers["X-Test"] == "yes")
        #expect(response.body == body)
        #expect(response.duration >= 0)
    }

    @Test("a non-2xx status is logged as a failure and the call still throws")
    func httpFailure() async throws {
        StubURLProtocol.stub = .response(statusCode: 429, headers: [:], body: Data())
        let sink = SpySink()

        await #expect(throws: GraphQLClientError.self) {
            try await makeClient(logger: sink).execute(LoggingTestQuery(id: "1"))
        }

        guard case .response(let response) = sink.events.last else {
            Issue.record("expected a response event, got \(sink.events)")
            return
        }
        #expect(response.outcome == .failure(statusCode: 429))
    }

    @Test("a transport error is logged as such and the call still throws")
    func transportFailure() async throws {
        StubURLProtocol.stub = .error(URLError(.notConnectedToInternet))
        let sink = SpySink()

        await #expect(throws: GraphQLClientError.self) {
            try await makeClient(logger: sink).execute(LoggingTestQuery(id: "1"))
        }

        guard case .response(let response) = sink.events.last else {
            Issue.record("expected a response event, got \(sink.events)")
            return
        }
        guard case .transportError = response.outcome else {
            Issue.record("expected a transport error, got \(response.outcome)")
            return
        }
        #expect(response.statusCode == nil)
    }
}

// MARK: - Doubles

private struct LoggingTestEntity: GraphQLDocumentConvertible, Codable, Sendable {
    let id: String?

    static func document(depth: Int) -> String { "id" }
}

private struct LoggingTestQuery: GraphQLQuery {
    typealias ResponseEntity = LoggingTestEntity

    static var objectRequested: String { "character" }

    let id: String
}

/// Records events synchronously so a test can assert right after the call.
private final class SpySink: APILogSinkContract, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [APILogEvent] = []

    var events: [APILogEvent] {
        lock.withLock { storage }
    }

    func log(_ event: APILogEvent) {
        lock.withLock { storage.append(event) }
    }
}

private final class StubURLProtocol: URLProtocol {
    enum Stub {
        case response(statusCode: Int, headers: [String: String], body: Data)
        case error(URLError)
    }

    nonisolated(unsafe) static var stub: Stub?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        switch Self.stub {
        case .response(let statusCode, let headers, let body):
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode,
                                           httpVersion: nil, headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case .error(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
        }
    }

    override func stopLoading() {}
}
