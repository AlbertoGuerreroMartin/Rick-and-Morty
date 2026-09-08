import Foundation

/// Assembles the operation text every query in this package sends. Shared here so
/// `GraphQLQuery` and `GraphQLPaginatedQuery` can't drift apart on the `result:` alias, which
/// is a contract with `GraphQLRootPayload`.
enum GraphQLOperation {

    static func document(rootField: String,
                         variableDefinitions: String,
                         arguments: String,
                         selection: String) -> String {
        // `result:` aliases the root field, so `data` is always `{ "result": ... }` regardless
        // of which field was asked for.
        """
        query\(parenthesized(variableDefinitions)) {
          result: \(rootField)\(parenthesized(arguments)) {
            \(indented(selection))
          }
        }
        """
    }

    /// Only the first line of a multi-line selection lands on the interpolation point's
    /// indentation; this re-indents the rest purely for readability in the inspector.
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
