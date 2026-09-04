import Foundation

/// A tiny, dependency-free GraphQL client built on `URLSession`.
///
/// GraphQL over HTTP is far simpler than the tooling around it suggests:
/// **every** request is a `POST` to **one** URL, with a JSON body shaped like
///
/// ```json
/// { "query": "query Characters($page: Int) { ... }", "variables": { "page": 1 } }
/// ```
///
/// There are no per-resource paths. In REST you'd hit `/character`,
/// `/character/1` and `/episode`; here all of those collapse into a single
/// endpoint, and *what* comes back is decided by the query document, not the URL.
/// That is the whole trade: you describe the exact shape you want, and the server
/// returns that shape — no over-fetching, no three round trips to build one screen.
public struct GraphQLClient: Sendable {

    /// The public Rick and Morty endpoint. https://rickandmortyapi.com/documentation
    public static func rickAndMorty(logger: any APILogSinkContract = NoOpAPILogger()) -> GraphQLClient {
        GraphQLClient(
            endpoint: URL(string: "https://rickandmortyapi.com/graphql")!,
            logger: logger
        )
    }

    let endpoint: URL
    let session: URLSession
    let logger: any APILogSinkContract

    /// - Parameters:
    ///   - session: injectable so a caller can supply its own configuration —
    ///     or a stubbed `URLProtocol` — instead of the default uncached session.
    ///   - logger: receives a `.request` event before each call leaves and a
    ///     `.response` event when it ends. Defaults to discarding them; the app
    ///     passes an `APILogStore` with a console logger attached.
    public init(
        endpoint: URL,
        session: URLSession = GraphQLClient.uncachedSession,
        logger: any APILogSinkContract = NoOpAPILogger()
    ) {
        self.endpoint = endpoint
        self.session = session
        self.logger = logger
    }

    /// A session with no `URLCache` at all.
    ///
    /// `URLSession.shared` would store every response in the system cache even
    /// though the request policy below never reads from it: a request's cache
    /// policy governs *lookups*, while *storage* is decided by the session's
    /// cache. Caching is a repository decision, made through `Storage` with a
    /// lifetime the app controls; a second copy in the system cache would be
    /// invisible to that policy. So the session has no cache to write to.
    public static let uncachedSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: configuration)
    }()

    public func execute<Query: GraphQLQuery>(_ query: Query) async throws -> Query.Response {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        // Never answer from a cache, even on an injected session that has one:
        // whether a response is reused is the repository's call, not URLCache's.
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // The document is static (one per operation type); the variables are the
        // per-call values. Keeping them separate is what lets a server cache and
        // validate the document, and it's also how you avoid string interpolation
        // bugs — never build a query by gluing user input into the document.
        request.httpBody = try JSONEncoder().encode(
            RequestBody(query: query.document, variables: query)
        )

        // Logged *before* any of the checks below, and unconditionally: a 500,
        // a GraphQL `errors` array and a body that does not decode are all
        // things the log exists to show, so the response record is written the
        // moment bytes arrive, not after the client has decided what it thinks.
        let requestRecord = APIRequestRecord(
            method: request.httpMethod ?? "POST",
            url: endpoint,
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody
        )
        logger.log(.request(requestRecord))

        let payload: Data
        let response: URLResponse
        do {
            (payload, response) = try await session.data(for: request)
        } catch let error as URLError {
            logger.log(.response(APIResponseRecord(
                id: requestRecord.id,
                method: requestRecord.method,
                url: endpoint,
                outcome: .transportError(description: error.localizedDescription),
                headers: [:],
                body: nil,
                duration: Date().timeIntervalSince(requestRecord.timestamp)
            )))
            throw GraphQLClientError.transport(error)
        }

        let http = response as? HTTPURLResponse
        let statusCode = http?.statusCode ?? 200
        logger.log(.response(APIResponseRecord(
            id: requestRecord.id,
            method: requestRecord.method,
            url: endpoint,
            outcome: (200..<300).contains(statusCode)
                ? .success(statusCode: statusCode)
                : .failure(statusCode: statusCode),
            headers: http?.stringHeaders ?? [:],
            body: payload,
            duration: Date().timeIntervalSince(requestRecord.timestamp)
        )))

        if let http, !(200..<300).contains(http.statusCode) {
            throw GraphQLClientError.httpStatus(http.statusCode)
        }

        let envelope: GraphQLResponse<Query.Response>
        do {
            envelope = try JSONDecoder().decode(GraphQLResponse<Query.Response>.self, from: payload)
        } catch let error as DecodingError {
            throw GraphQLClientError.decoding(error)
        }

        // A GraphQL server answers 200 OK even when the operation failed: failures
        // live in the `errors` array, never in the status code. Checking only
        // `response.statusCode` — the REST habit — would silently swallow them.
        if let errors = envelope.errors, !errors.isEmpty {
            throw GraphQLClientError.server(errors)
        }
        guard let data = envelope.data else {
            throw GraphQLClientError.emptyPayload
        }
        return data
    }

    /// The wire format of a GraphQL request. `variables` is the query object itself.
    private struct RequestBody<Variables: Encodable>: Encodable {
        let query: String
        let variables: Variables
    }
}

private extension HTTPURLResponse {
    /// `allHeaderFields` is `[AnyHashable: Any]` for historical reasons; on the
    /// wire both sides are always strings, so this is a lossless narrowing.
    var stringHeaders: [String: String] {
        allHeaderFields.reduce(into: [:]) { headers, pair in
            guard let name = pair.key as? String else { return }
            headers[name] = "\(pair.value)"
        }
    }
}
