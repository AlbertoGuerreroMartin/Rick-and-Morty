import Foundation

/// A tiny, dependency-free GraphQL client built on `URLSession`. Every request is a `POST` to one
/// URL; what comes back is decided by the query document, not the URL.
public struct GraphQLClient: Sendable {

    /// The public Rick and Morty endpoint. https://rickandmortyapi.com/documentation
    public static func rickAndMorty(logger: any APILogSinkContract = NoOpAPILogger()) -> GraphQLClient {
        GraphQLClient(
            endpoint: URL(string: "https://rickandmortyapi.com/graphql")!,
            logger: logger
        )
    }

    /// JustWatch's public but unofficial, undocumented GraphQL endpoint. Shares the same client
    /// type and logger as ``rickAndMorty(logger:)``, so its calls show in the inspector too. No
    /// schema introspection (the server disables it); a caller must treat a failure as normal and
    /// degrade rather than surface an error — see `EpisodesUseCase`.
    public static func justWatch(logger: any APILogSinkContract = NoOpAPILogger()) -> GraphQLClient {
        GraphQLClient(
            endpoint: URL(string: "https://apis.justwatch.com/graphql")!,
            logger: logger
        )
    }

    let endpoint: URL
    let session: URLSession
    let logger: any APILogSinkContract

    /// - Parameters:
    ///   - session: injectable, e.g. for a stubbed `URLProtocol` in tests.
    ///   - logger: receives `.request`/`.response` events; defaults to discarding them.
    public init(
        endpoint: URL,
        session: URLSession = GraphQLClient.uncachedSession,
        logger: any APILogSinkContract = NoOpAPILogger()
    ) {
        self.endpoint = endpoint
        self.session = session
        self.logger = logger
    }

    /// No `URLCache`: caching is a repository decision made through `Storage`, so the session
    /// must have no cache of its own to write a second, invisible copy into.
    public static let uncachedSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: configuration)
    }()

    public func execute<Query: GraphQLQuery>(_ query: Query) async throws -> Query.Response {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        // Never answer from a cache, even on an injected session that has one: reuse is the
        // repository's call, not URLCache's.
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Document and variables kept separate: lets the server cache/validate the document, and
        // avoids string-interpolation bugs.
        request.httpBody = try JSONEncoder().encode(
            RequestBody(query: query.document, variables: query)
        )

        // Logged unconditionally, before any check below, so a 500 or undecodable body still
        // gets a response record.
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

        // A GraphQL server answers 200 OK even on failure; failures live in the `errors` array.
        if let errors = envelope.errors, !errors.isEmpty {
            throw GraphQLClientError.server(errors)
        }
        guard let data = envelope.data else {
            throw GraphQLClientError.emptyPayload
        }
        return data
    }

    /// The wire format of a GraphQL request; `variables` is the query object itself.
    private struct RequestBody<Variables: Encodable>: Encodable {
        let query: String
        let variables: Variables
    }
}

private extension HTTPURLResponse {
    /// `allHeaderFields` is `[AnyHashable: Any]` for historical reasons; narrowing to strings
    /// is lossless.
    var stringHeaders: [String: String] {
        allHeaderFields.reduce(into: [:]) { headers, pair in
            guard let name = pair.key as? String else { return }
            headers[name] = "\(pair.value)"
        }
    }
}
