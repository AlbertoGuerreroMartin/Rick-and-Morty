import Foundation

/// One GraphQL operation: the document (the query text) plus the variables it needs.
///
/// The conforming type *is* the variables object — its stored properties are encoded
/// straight into the `"variables"` field of the request body. An operation that takes
/// no variables is just a struct with no stored properties (it encodes as `{}`).
///
/// ```swift
/// struct CharactersQuery: GraphQLQuery {
///     typealias ResponseEntity = CharacterEntity
///     static var objectRequested: String { "characters" }
///     let page: Int                    // -> {"variables": {"page": 1}}
/// }
/// ```
public protocol GraphQLQuery: Encodable {
    /// The entity the root field selects. Its `@Document` selection set is what
    /// gets pasted into the operation, and it is also the decoded payload.
    associatedtype ResponseEntity: GraphQLDocumentConvertible, Decodable

    /// The Swift shape of the `"data"` object the server sends back.
    ///
    /// The root field is aliased to `result` (see `document`), so the default
    /// covers every single-root-field operation and conformers can leave it out.
    /// Override it only for a document that selects more than one root field.
    associatedtype Response: Decodable = GraphQLRootPayload<ResponseEntity>

    /// The name of the root field in the schema, e.g. `"characters"`.
    static var objectRequested: String { get }

    /// The operation text, exactly as you would paste it into a GraphQL playground.
    var document: String { get }
}
