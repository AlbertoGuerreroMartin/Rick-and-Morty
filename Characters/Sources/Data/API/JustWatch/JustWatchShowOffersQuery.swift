//
//  JustWatchShowOffersQuery.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking

/// Every streaming offer JustWatch has for one show, episode by episode.
///
/// Duplicate of the Episodes feature's identical query: feature packages don't import each
/// other, and the document text must stay byte-for-byte identical since `cacheIdentifier`
/// hashes the document text, so a mismatch would miss the shared cache key.
///
/// Hand-written, not a generated `GraphQLQuery`: JustWatch's endpoint is unofficial with
/// introspection disabled, and the generated builders can't express `node(id:)`'s inline
/// fragment or its arguments.
struct JustWatchShowOffersQuery: GraphQLQuery {
    typealias ResponseEntity = JustWatchShowEntity

    static var objectRequested: String { "node" }

    /// JustWatch's node id for Rick and Morty; avoids a search request to rediscover a fixed id.
    static let rickAndMortyNodeID = "ts20233"

    let id: String
    /// ISO 3166-1 country. Offers are per-territory: JustWatch's HBO Max episode UUIDs are
    /// only accurate in some (checked 2026-09-07) — `US`/`MX`/`AR` agree on all 91 episodes;
    /// `ES`/`PT`/`NL`/`FR` carry a wrong pilot UUID; `DE`/`IT`/`GB` return marketing-site URLs.
    let country: String
    /// ISO 639-1 language, for localized `content` fields; only the numbering is read from them.
    let language: String

    init(id: String = rickAndMortyNodeID,
         country: String = "US",
         language: String = "en") {
        self.id = id
        self.country = country
        self.language = language
    }

    /// The `result:` alias matches what `GraphQLRootPayload` expects to decode.
    var document: String {
        """
        query($id: ID!, $country: Country!, $language: Language!) {
          result: node(id: $id) {
            \(Self.indented(ResponseEntity.document))
          }
        }
        """
    }

    /// Cosmetic indentation for the request inspector; GraphQL ignores whitespace.
    private static func indented(_ selection: String) -> String {
        selection.split(separator: "\n", omittingEmptySubsequences: false)
                 .joined(separator: "\n    ")
    }
}
