//
//  GraphQLPageResponse.swift
//  Networking
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import Foundation

public struct GraphQLPageResponse<ResponseEntity: Decodable>: Decodable {
    public let info: GraphQLPageInfo
    public let results: [ResponseEntity]

    public init(info: GraphQLPageInfo, results: [ResponseEntity]) {
        self.info = info
        self.results = results
    }
}

// Conditional, not a constraint: tightening to `Codable & Sendable` would push the requirement
// onto every entity in the app, cached or not.
extension GraphQLPageResponse: Encodable where ResponseEntity: Encodable {}

extension GraphQLPageResponse: Sendable where ResponseEntity: Sendable {}

public struct GraphQLPageInfo: Codable, Sendable {
    public let count: Int?
    public let pages: Int?
    /// The next page number, or `nil` when you've reached the end.
    public let next: Int?

    public init(count: Int?, pages: Int?, next: Int?) {
        self.count = count
        self.pages = pages
        self.next = next
    }
}

// Written by hand, not by `@Document`: `[ResponseEntity?]?` never conforms to
// `GraphQLDocumentConvertible`, so `results` would get no selection set.
extension GraphQLPageInfo: GraphQLDocumentConvertible {
    public static func document(depth: Int) -> String {
        """
        count
        pages
        next
        """
    }
}

extension GraphQLPageResponse: GraphQLDocumentConvertible where ResponseEntity: GraphQLDocumentConvertible {
    /// - Note: `depth` passes through to `ResponseEntity`, not decremented — the page wrapper
    ///   isn't a schema level, so decrementing would shrink every paginated selection by one.
    public static func document(depth: Int) -> String {
        [
            GraphQLField.selection("info", GraphQLPageInfo.document(depth: depth)),
            GraphQLField.selection("results", ResponseEntity.document(depth: depth))
        ].joined(separator: "\n")
    }
}
