//
//  GraphQLField.swift
//  Networking
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import Foundation

/// Resolves one property into its GraphQL selection.
///
/// A macro only sees the syntax of the declaration it is attached to, so
/// `@Document` on `CharacterEntity` cannot know whether `Place` is itself a
/// document type — it only sees the spelling `Place?`. The decision is therefore
/// deferred to runtime: the generated code hands the property's type over and
/// this asks it directly.
public enum GraphQLField {

    /// - Returns: `name` for a scalar, `name { ... }` for a nested document type,
    ///   or `nil` when the budget is spent — dropping the field, because an
    ///   object field with no selection set is not valid GraphQL.
    public static func resolve<T>(_ name: String, _ type: T.Type, depth: Int) -> String? {
        guard let nested = type as? any GraphQLDocumentConvertible.Type else {
            return name
        }
        guard depth > 1 else { return nil }
        return "\(name) { \(nested.document(depth: depth - 1)) }"
    }
}
