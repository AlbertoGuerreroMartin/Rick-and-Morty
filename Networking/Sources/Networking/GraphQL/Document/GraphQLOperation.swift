import Foundation

/// Assembles the operation text every query in this package sends.
///
/// Both `GraphQLQuery` and `GraphQLPaginatedQuery` produce the same skeleton and
/// differ only in what fills two holes: the root field's `arguments` and the
/// `selection` set. Keeping the skeleton here is what stops the two default
/// implementations from drifting apart — in particular the `result:` alias,
/// which is a contract with `GraphQLRootPayload` and has to be spelled the same
/// way by every builder.
enum GraphQLOperation {

    static func document(rootField: String,
                         variableDefinitions: String,
                         arguments: String,
                         selection: String) -> String {
        // `result:` is a field *alias*: it renames the root field in the response,
        // so `data` is always `{ "result": ... }` no matter which field was asked
        // for. Aliases are a client-side feature of the spec, nothing to enable
        // server-side. See `GraphQLRootPayload`.
        """
        query\(parenthesized(variableDefinitions)) {
          result: \(rootField)\(parenthesized(arguments)) {
            \(indented(selection))
          }
        }
        """
    }

    /// A selection set arrives as its own multi-line string, so only its first
    /// line lands on the indentation of the interpolation point. GraphQL ignores
    /// whitespace entirely — this is purely so the document reads as written when
    /// you look at it in the query inspector.
    private static func indented(_ selection: String) -> String {
        selection.split(separator: "\n", omittingEmptySubsequences: false)
                 .joined(separator: "\n    ")
    }

    /// An empty argument or variable list must be omitted entirely — `query()` and
    /// `characters()` are both syntax errors.
    private static func parenthesized(_ body: String) -> String {
        body.isEmpty ? "" : "(\(body))"
    }
}
