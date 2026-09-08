//
//  GraphQLField.swift
//  Networking
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import Foundation

/// Resolves one property into its GraphQL selection. Deferred to runtime since a macro can only
/// see a property's type spelling, not whether it conforms to `GraphQLDocumentConvertible`.
public enum GraphQLField {

    /// - Returns: `name` for a scalar, `name { ... }` for a nested document type, or `nil` when
    ///   depth is spent (an object field with no selection is invalid GraphQL).
    public static func resolve<T>(_ name: String, _ type: T.Type, depth: Int) -> String? {
        guard let nested = type as? any GraphQLDocumentConvertible.Type else {
            return name
        }
        guard depth > 1 else { return nil }
        return selection(name, nested.document(depth: depth - 1))
    }

    /// An object field with its selection set indented one field per line, purely for humans
    /// reading the document (GraphQL ignores whitespace) — mainly in the API log.
    public static func selection(_ name: String, _ body: String) -> String {
        let indented = body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "  \($0)" }
            .joined(separator: "\n")
        return "\(name) {\n\(indented)\n}"
    }
}
