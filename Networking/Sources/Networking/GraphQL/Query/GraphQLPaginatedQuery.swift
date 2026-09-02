//
//  GraphQLPaginatedQuery.swift
//  Networking
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import Foundation

/// A query whose root field returns a page (`info` + `results`) rather than the
/// entity directly.
///
/// The `where` clause pins `Response` for every conformer, so a paginated query
/// declares only its `ResponseEntity` and `objectRequested`.
public protocol GraphQLPaginatedQuery: GraphQLQuery where Response == GraphQLRootPayload<GraphQLPageResponse<ResponseEntity>> {
    var page: Int? { get }
}

extension GraphQLPaginatedQuery {
    public var document: String {
        let declaredProperties = declaredProperties()

        // The paginated root field doesn't take its variables flat: `page` is an
        // argument of its own and everything else is nested inside `filter`.
        let filters = declaredProperties
            .map(\.propertyIdentifier)
            .filter { $0 != "page" }
            .map { "\($0): $\($0)" }
        let arguments = [
            page != nil ? "page: $page" : nil,
            filters.isEmpty ? nil : "filter: { \(filters.joined(separator: ", ")) }"
        ].compactMap { $0 }.joined(separator: ", ")

        return GraphQLOperation.document(
            rootField: Self.objectRequested,
            variableDefinitions: queryParametersDefinitions(declaredProperties),
            arguments: arguments,
            selection: GraphQLPageResponse<ResponseEntity>.document
        )
    }
}
