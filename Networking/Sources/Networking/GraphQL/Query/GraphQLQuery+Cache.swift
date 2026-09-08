//
//  GraphQLQuery+Cache.swift
//  Networking
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import CryptoKit
import Foundation

extension GraphQLQuery {

    /// A stable identity for this exact operation, suitable as a cache key: `objectRequested`
    /// (readable root field), a hash of the document — so an entity gaining a `@Document` field
    /// ages old entries out instead of failing to decode — and the sorted-key variables JSON.
    public var cacheIdentifier: String {
        "\(Self.objectRequested)|\(Self.sha256Hex(document))|\(variablesJSON)"
    }

    /// Hashed, not embedded whole: the document runs to hundreds of characters and only its
    /// identity matters here.
    private static func sha256Hex(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
