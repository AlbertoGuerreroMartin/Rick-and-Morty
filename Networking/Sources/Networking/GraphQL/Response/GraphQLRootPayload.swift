//
//  GraphQLRootPayload.swift
//  Networking
//
//  Created by Alberto Guerrero Martin on 02/09/2026.
//

import Foundation

/// The `data` object of every operation this package builds.
///
/// The document builders alias the root field to a fixed `result` key
/// (`result: characters(...)`, `result: character(...)`), so the shape of `data`
/// no longer depends on which field was requested. That is what lets a single
/// generic type stand in for the per-query `Response` struct each operation used
/// to declare only to spell the server's field name.
///
/// Aliases are resolved entirely by the client — the response key is the alias
/// when one is present, otherwise the field name — so this needs nothing from
/// the schema.
///
/// - Note: This assumes exactly *one* root field per operation. Selecting two
///   (`characters` and `episodes` in a single round trip) needs its own `Response`
///   type with a property per alias.
public struct GraphQLRootPayload<Result: Decodable>: Decodable {
    /// The value of the aliased root field.
    public let result: Result

    public init(result: Result) {
        self.result = result
    }
}

// Conditional, for the same reason as `GraphQLPageResponse`: only the payloads
// that actually get written to a cache need to be encodable, and requiring it of
// every `Response` would ripple out to every query in the app.

extension GraphQLRootPayload: Encodable where Result: Encodable {}

extension GraphQLRootPayload: Sendable where Result: Sendable {}
