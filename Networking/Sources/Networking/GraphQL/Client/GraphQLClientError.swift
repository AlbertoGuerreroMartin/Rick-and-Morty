import Foundation

/// Everything that can go wrong between "I have a query" and "I have a model".
public enum GraphQLClientError: LocalizedError {
    /// The request never reached the server (offline, DNS, timeout...).
    case transport(URLError)
    /// A non-2xx HTTP status. Rare in GraphQL — see `.server` below.
    case httpStatus(Int)
    /// The JSON came back, but it did not match the `Response` type.
    case decoding(DecodingError)
    /// The server ran the operation and reported failures in the `errors` array.
    /// Note this arrives with HTTP **200 OK**, which is the single biggest
    /// difference from REST error handling.
    case server([GraphQLServerError])
    /// `data` was null and there were no errors — a malformed response.
    case emptyPayload

    public var errorDescription: String? {
        switch self {
        case .transport(let error):
            return "Network problem: \(error.localizedDescription)"
        case .httpStatus(let code):
            return "The server answered with HTTP \(code)."
        case .decoding(let error):
            return "The response didn't match the expected shape: \(error)"
        case .server(let errors):
            return errors.map(\.message).joined(separator: "\n")
        case .emptyPayload:
            return "The server returned no data."
        }
    }
}
