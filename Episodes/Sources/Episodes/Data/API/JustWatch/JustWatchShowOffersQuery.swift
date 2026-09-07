//
//  JustWatchShowOffersQuery.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking

/// Every streaming offer JustWatch has for one show, episode by episode.
///
/// This is the only operation in the app that does not go to rickandmortyapi,
/// and the only one that writes its own document. Both follow from the endpoint
/// being unofficial: introspection is disabled, so the schema below is pinned by
/// observation, and the generated builders cannot express it anyway — the root
/// field is `node(id:)`, which returns the `Node` interface and needs an inline
/// fragment to reach a `Show`, and three of the fields take arguments the
/// builders have no way to attach.
///
/// What is *not* hand-written is everything else: it is a `GraphQLQuery` like
/// any other, so the variables are its stored properties, the client sends it
/// unchanged, the API log shows it, and `cacheIdentifier` — the document's hash
/// plus the sorted variables — comes for free. Editing the document below
/// therefore re-keys the cache automatically; last week's entry is simply no
/// longer addressed rather than read back into a shape that has moved on.
struct JustWatchShowOffersQuery: GraphQLQuery {
    typealias ResponseEntity = JustWatchShowEntity

    /// The root field. `node` is JustWatch's Relay-style entry point: one field
    /// that returns anything addressable by id.
    static var objectRequested: String { "node" }

    /// JustWatch's node id for Rick and Morty, hard-coded.
    ///
    /// The alternative is a search operation before every lookup — a second
    /// request, on an unofficial endpoint, to rediscover an id that has not
    /// changed since the show was added. This app is about exactly one show, so
    /// the id is as much a constant here as the API's own base URL is.
    static let rickAndMortyNodeID = "ts20233"

    let id: String
    /// An ISO 3166-1 country code. Offers are per-territory: the same episode is
    /// on different services in different countries, and HBO Max is not sold in
    /// all of them.
    ///
    /// The default is `US`, and it is not the country the app is used in. HBO
    /// Max's episode ids are global — the Spanish and American hbomax.com sites
    /// list the same UUID for every episode of this show — but JustWatch's
    /// *copy* of them is only accurate in some territories. Checked on
    /// 2026-09-07 against the hbomax.com episode pages: `US`, `MX` and `AR`
    /// agree on all 91 episodes; `ES`, `PT`, `NL` and `FR` each carry a wrong
    /// UUID for the pilot, which opened the wrong episode on a real device; and
    /// `DE`, `IT` and `GB` return marketing-site URLs rather than player links.
    /// Asking the territory whose data is right is what makes the button open
    /// the episode it says it will.
    let country: String
    /// An ISO 639-1 language code, for the localized `content` fields. Only the
    /// numbering is read out of them, so this only has to be a language the
    /// server accepts.
    let language: String

    init(id: String = rickAndMortyNodeID,
         country: String = "US",
         language: String = "en") {
        self.id = id
        self.country = country
        self.language = language
    }

    /// The operation text, written out rather than built.
    ///
    /// The `result:` alias is not decoration: it is the contract with
    /// `GraphQLRootPayload`, which every response in this app decodes through, so
    /// a document that spelled the root field plainly would decode to nothing.
    /// `Country` and `Language` are the server's own scalar types — an unknown
    /// value there comes back as a GraphQL error, which the client surfaces as
    /// `GraphQLClientError.server` rather than as an empty result.
    var document: String {
        """
        query($id: ID!, $country: Country!, $language: Language!) {
          result: node(id: $id) {
            \(Self.indented(ResponseEntity.document))
          }
        }
        """
    }

    /// Lines the selection set up under the root field. GraphQL ignores
    /// whitespace entirely; this is for the person reading the document in the
    /// request inspector, and mirrors what `GraphQLOperation` does for the
    /// generated queries.
    private static func indented(_ selection: String) -> String {
        selection.split(separator: "\n", omittingEmptySubsequences: false)
                 .joined(separator: "\n    ")
    }
}
