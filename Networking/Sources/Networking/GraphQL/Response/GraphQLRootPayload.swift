//
//  GraphQLRootPayload.swift
//  Networking
//
//  Created by Alberto Guerrero Martin on 02/09/2026.
//

import Foundation

/// The `data` object of every operation this package builds. Document builders alias the root
/// field to a fixed `result` key, so one generic type stands in for what each query used to
/// declare its own `Response` struct only to spell the server's field name.
///
/// - Note: Assumes exactly one root field per operation. Selecting two in a single round trip
///   needs its own `Response` type with a property per alias.
public struct GraphQLRootPayload<Result: Decodable>: Decodable {
    public let result: Result

    public init(result: Result) {
        self.result = result
    }
}

// Conditional, like `GraphQLPageResponse`: only cached payloads need to be encodable, and
// requiring it of every `Response` would ripple out to every query in the app.
extension GraphQLRootPayload: Encodable where Result: Encodable {}

extension GraphQLRootPayload: Sendable where Result: Sendable {}
