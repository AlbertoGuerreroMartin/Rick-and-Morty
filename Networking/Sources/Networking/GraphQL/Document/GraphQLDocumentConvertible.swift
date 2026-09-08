//
//  GraphQLDocumentConvertible.swift
//  Networking
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import Foundation

public protocol GraphQLDocumentConvertible {
    /// The selection set for this type, expanded to at most `depth` levels of
    /// nesting. Nested object fields consume one level each; scalars are free.
    static func document(depth: Int) -> String
}

extension GraphQLDocumentConvertible {
    /// GraphQL schemas are cyclic (`Character -> Episode -> Character`), so unbounded expansion
    /// never terminates; three levels covers every screen in this app.
    public static var defaultDepth: Int { 3 }

    public static var document: String {
        document(depth: defaultDepth)
    }
}
