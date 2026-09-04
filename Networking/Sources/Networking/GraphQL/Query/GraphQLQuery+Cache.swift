//
//  GraphQLQuery+Cache.swift
//  Networking
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import CryptoKit
import Foundation

extension GraphQLQuery {

    /// A stable identity for this exact operation, suitable as a cache key.
    ///
    /// Three parts, each earning its place:
    ///
    /// - **`objectRequested`** — the root field. Cheap, and it makes a key
    ///   readable when you print one while debugging.
    /// - **A hash of the document.** This is the part that is easy to leave out
    ///   and expensive to leave out. The document *is* the shape of the response:
    ///   adding a field to an entity's `@Document` changes the selection set, so
    ///   yesterday's cached JSON no longer has the field the new model requires.
    ///   Folding the document into the key means the old entries simply stop
    ///   being addressed — they age out and get swept — instead of being read
    ///   back and failing to decode. A model change can never serve stale-shaped
    ///   data, and no manual "bump the cache version" step is needed.
    /// - **The encoded variables.** Page 1 and page 2 are different values of the
    ///   same operation. `variablesJSON` sorts its keys, so the string depends on
    ///   what is being asked, never on the order the encoder happened to visit
    ///   properties in.
    ///
    /// It is deterministic for *every* query, paginated or not: both come from
    /// the same document builder and the same variables encoder.
    public var cacheIdentifier: String {
        "\(Self.objectRequested)|\(Self.sha256Hex(document))|\(variablesJSON)"
    }

    /// The document is hashed rather than embedded whole: it runs to hundreds of
    /// characters and only its *identity* matters here.
    private static func sha256Hex(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
