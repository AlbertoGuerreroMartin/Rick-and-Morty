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
    public static let rickAndMorty = GraphQLClient(
        endpoint: URL(string: "https://rickandmortyapi.com/graphql")!
    )

    let endpoint: URL
    let session: URLSession

    /// - Parameter session: injectable so a caller can supply its own
    ///   configuration — or a stubbed `URLProtocol` — instead of `.shared`.
    public init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    public func execute<Query: GraphQLQuery>(_ query: Query) async throws -> Query.Response {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // The document is static (one per operation type); the variables are the
        // per-call values. Keeping them separate is what lets a server cache and
        // validate the document, and it's also how you avoid string interpolation
        // bugs — never build a query by gluing user input into the document.
        request.httpBody = try JSONEncoder().encode(
            RequestBody(query: query.document, variables: query)
        )

        let payload: Data
        let response: URLResponse
        do {
            (payload, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw GraphQLClientError.transport(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
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
