//
//  JustWatchShowOffersQuery.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking

/// Every streaming offer JustWatch has for one show. The only hand-written document: introspection
/// is disabled here, and `node(id:)` needs an inline fragment plus arguments builders can't express.
struct JustWatchShowOffersQuery: GraphQLQuery {
    typealias ResponseEntity = JustWatchShowEntity

    static var objectRequested: String { "node" }

    static let rickAndMortyNodeID = "ts20233"

    let id: String
    /// Default `US`: checked 2026-09-07, `ES`/`PT`/`NL`/`FR` carry a wrong pilot UUID and
    /// `DE`/`IT`/`GB` return marketing URLs instead of player links.
    let country: String
    let language: String

    init(id: String = rickAndMortyNodeID,
         country: String = "US",
         language: String = "en") {
        self.id = id
        self.country = country
        self.language = language
    }

    /// `result:` alias is required by `GraphQLRootPayload`.
    var document: String {
        """
        query($id: ID!, $country: Country!, $language: Language!) {
          result: node(id: $id) {
            \(Self.indented(ResponseEntity.document))
          }
        }
        """
    }

    /// Cosmetic only, for the request inspector; GraphQL ignores whitespace.
    private static func indented(_ selection: String) -> String {
        selection.split(separator: "\n", omittingEmptySubsequences: false)
                 .joined(separator: "\n    ")
    }
}
