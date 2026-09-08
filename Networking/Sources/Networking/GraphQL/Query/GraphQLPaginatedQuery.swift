//
//  GraphQLPaginatedQuery.swift
//  Networking
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import Foundation

/// A query whose root field returns a page (`info` + `results`) rather than the entity
/// directly. The `where` clause pins `Response`, so a conformer declares only `ResponseEntity`
/// and `objectRequested`.
public protocol GraphQLPaginatedQuery: GraphQLQuery where Response == GraphQLRootPayload<GraphQLPageResponse<ResponseEntity>> {
    var page: Int? { get }
}

extension GraphQLPaginatedQuery {
    public var document: String {
        let declaredProperties = declaredProperties()

        // `page` is its own argument; everything else nests inside `filter`.
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
