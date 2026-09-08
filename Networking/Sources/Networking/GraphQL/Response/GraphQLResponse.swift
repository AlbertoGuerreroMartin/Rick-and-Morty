import Foundation

/// `data` and `errors` can both be present: GraphQL supports partial results, where some
/// fields resolved and others failed.
struct GraphQLResponse<Payload: Decodable>: Decodable {
    let data: Payload?
    let errors: [GraphQLServerError]?
}

/// One entry from the response's `errors` array.
public struct GraphQLServerError: Decodable, Sendable {
    public let message: String
    public let locations: [Location]?

    public struct Location: Decodable, Sendable {
        public let line: Int
        public let column: Int
    }
}
