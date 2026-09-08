//
//  JustWatchShowEntityDecodingTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking
import Testing
@testable import Characters

/// Pinned by a real response since JustWatch's schema can't be introspected; every field must decode `null`.
@Suite("JustWatchShowEntity decoding")
struct JustWatchShowEntityDecodingTests {

    // MARK: - The real response

    @Test("a real response decodes through the root payload")
    func realResponseDecodes() throws {
        let show = try decode(Self.realResponse)

        #expect(show.seasons?.count == 2)
        #expect(show.seasons?.first?.content?.seasonNumber == 1)
        #expect(show.seasons?.first?.episodes?.count == 3)
        #expect(show.seasons?.last?.episodes?.count == 2)
    }

    @Test("an episode carries its numbering and every offer the country has")
    func episodesCarryTheirOffers() throws {
        let episode = try #require(try decode(Self.realResponse).seasons?.first?.episodes?.first)

        #expect(episode.content?.seasonNumber == 1)
        #expect(episode.content?.episodeNumber == 1)
        // Includes services this feature ignores; the entity must survive them.
        #expect(episode.offers?.compactMap { $0.package?.technicalName }
            == ["hulu", "amazonhbomax", "max", "max"])
    }

    /// The tracking parameter and the duplicate `max` offer are kept verbatim; dropping either is the mapper's job.
    @Test("a deeplink arrives exactly as the server spelled it")
    func deeplinksAreVerbatim() throws {
        let offers = try #require(try decode(Self.realResponse).seasons?.first?.episodes?.first?.offers)
        let max = offers.filter { $0.package?.technicalName == "max" }

        #expect(max.count == 2)
        #expect(max.first?.deeplinkURL == max.last?.deeplinkURL)
        #expect(max.first?.deeplinkURL?.hasSuffix("?utm_source=universal_search") == true)
    }

    // MARK: - Everything the server may legally answer instead

    @Test("a show with no seasons decodes")
    func nullSeasonsDecode() throws {
        #expect(try decode(#"{"data": {"result": {"seasons": null}}}"#).seasons == nil)
    }

    @Test("an absent field decodes as nil rather than failing")
    func absentFieldsDecode() throws {
        #expect(try decode(#"{"data": {"result": {}}}"#).seasons == nil)
    }

    @Test("nulls at every level decode")
    func nullsEverywhereDecode() throws {
        let show = try decode(#"""
        {
          "data": {
            "result": {
              "seasons": [
                {
                  "content": null,
                  "episodes": [
                    { "content": null, "offers": null },
                    {
                      "content": { "seasonNumber": null, "episodeNumber": null },
                      "offers": [{ "package": null, "deeplinkURL": null }]
                    }
                  ]
                }
              ]
            }
          }
        }
        """#)

        let season = try #require(show.seasons?.first)
        #expect(season.content == nil)
        #expect(season.episodes?.count == 2)
        #expect(season.episodes?.first?.offers == nil)
        #expect(season.episodes?.last?.offers?.first?.package == nil)
        #expect(season.episodes?.last?.offers?.first?.deeplinkURL == nil)
    }

    /// See `JustWatchOfferEntity.deeplinkURL`: `String`, not `URL`, is what makes this survivable.
    @Test("a deeplink that is not a URL still decodes")
    func malformedDeeplinkDecodes() throws {
        let show = try decode(#"""
        {"data": {"result": {"seasons": [{"content": {"seasonNumber": 1}, "episodes": [
          {"content": {"seasonNumber": 1, "episodeNumber": 1},
           "offers": [{"package": {"technicalName": "max"}, "deeplinkURL": "not a url at all"}]}
        ]}]}}}
        """#)

        #expect(show.seasons?.first?.episodes?.first?.offers?.first?.deeplinkURL == "not a url at all")
    }

    // MARK: - The document

    @Test("the selection set asks for exactly what the entities decode")
    func documentMatchesTheEntities() {
        let document = JustWatchShowEntity.document

        #expect(document.hasPrefix("... on Show {"))
        #expect(document.contains("seasons {"))
        #expect(document.contains("content(country: $country, language: $language) {"))
        #expect(document.contains("seasonNumber"))
        #expect(document.contains("episodeNumber"))
        #expect(document.contains("offers(country: $country, platform: WEB) {"))
        #expect(document.contains("technicalName"))
        #expect(document.contains("deeplinkURL(platform: IOS)"))
    }

    @Test("the depth does not change the selection set")
    func documentIgnoresDepth() {
        #expect(JustWatchShowEntity.document(depth: 1) == JustWatchShowEntity.document(depth: 9))
    }

    // MARK: - Helpers

    private func decode(_ json: String) throws -> JustWatchShowEntity {
        try JustWatchShowEntity.decoded(from: json)
    }

    private static var realResponse: String { JustWatchShowEntity.liveUSResponse }
}

// MARK: - Fixtures

extension JustWatchShowEntity {

    /// Decodes a whole response body, envelope included, so fixtures paste straight from the network log.
    static func decoded(from json: String) throws -> JustWatchShowEntity {
        struct Envelope: Decodable {
            let data: GraphQLRootPayload<JustWatchShowEntity>
        }

        // GraphQLResponse is internal to Networking, so the `data` key is peeled here.
        return try JSONDecoder().decode(Envelope.self, from: Data(json.utf8)).data.result
    }

    /// A real US-region response, trimmed to two seasons; the package's only fixture, kept inline.
    static let liveUSResponse = #"""
        {
          "data": {
            "result": {
              "seasons": [
                {
                  "content": {
                    "seasonNumber": 1
                  },
                  "episodes": [
                    {
                      "content": {
                        "seasonNumber": 1,
                        "episodeNumber": 1
                      },
                      "offers": [
                        {
                          "package": {
                            "technicalName": "hulu"
                          },
                          "deeplinkURL": "https://www.hulu.com/watch/f88cfbf8-c514-4126-a3ee-da0413f79af6"
                        },
                        {
                          "package": {
                            "technicalName": "amazonhbomax"
                          },
                          "deeplinkURL": "https://watch.amazon.com/watch?gti=amzn1.dv.gti.ba209947-9c34-4dce-872a-58136180287c"
                        },
                        {
                          "package": {
                            "technicalName": "max"
                          },
                          "deeplinkURL": "https://play.hbomax.com/video/watch/ef7d1c40-2ecc-471a-81a5-7fe06400240a?utm_source=universal_search"
                        },
                        {
                          "package": {
                            "technicalName": "max"
                          },
                          "deeplinkURL": "https://play.hbomax.com/video/watch/ef7d1c40-2ecc-471a-81a5-7fe06400240a?utm_source=universal_search"
                        }
                      ]
                    },
                    {
                      "content": {
                        "seasonNumber": 1,
                        "episodeNumber": 2
                      },
                      "offers": [
                        {
                          "package": {
                            "technicalName": "hulu"
                          },
                          "deeplinkURL": "https://www.hulu.com/watch/ff2d6bff-6c28-411b-bb4c-1632487eb5bb"
                        },
                        {
                          "package": {
                            "technicalName": "amazonhbomax"
                          },
                          "deeplinkURL": "https://watch.amazon.com/watch?gti=amzn1.dv.gti.2ec8ed42-88f4-473b-8cc7-19507e15c533"
                        },
                        {
                          "package": {
                            "technicalName": "max"
                          },
                          "deeplinkURL": "https://play.hbomax.com/video/watch/98f5603d-7461-4968-8399-72da5d9302d8?utm_source=universal_search"
                        },
                        {
                          "package": {
                            "technicalName": "max"
                          },
                          "deeplinkURL": "https://play.hbomax.com/video/watch/98f5603d-7461-4968-8399-72da5d9302d8?utm_source=universal_search"
                        }
                      ]
                    },
                    {
                      "content": {
                        "seasonNumber": 1,
                        "episodeNumber": 3
                      },
                      "offers": [
                        {
                          "package": {
                            "technicalName": "hulu"
                          },
                          "deeplinkURL": "https://www.hulu.com/watch/e7de04f4-6f5f-4c40-bc07-5ae43a021c99"
                        },
                        {
                          "package": {
                            "technicalName": "amazonhbomax"
                          },
                          "deeplinkURL": "https://watch.amazon.com/watch?gti=amzn1.dv.gti.19228b55-054d-45d5-af5f-63cdc2a815d8"
                        },
                        {
                          "package": {
                            "technicalName": "max"
                          },
                          "deeplinkURL": "https://play.hbomax.com/video/watch/fcc7d036-2a20-4f3d-b20b-1bd1a2f23672?utm_source=universal_search"
                        },
                        {
                          "package": {
                            "technicalName": "max"
                          },
                          "deeplinkURL": "https://play.hbomax.com/video/watch/fcc7d036-2a20-4f3d-b20b-1bd1a2f23672?utm_source=universal_search"
                        }
                      ]
                    }
                  ]
                },
                {
                  "content": {
                    "seasonNumber": 2
                  },
                  "episodes": [
                    {
                      "content": {
                        "seasonNumber": 2,
                        "episodeNumber": 1
                      },
                      "offers": [
                        {
                          "package": {
                            "technicalName": "hulu"
                          },
                          "deeplinkURL": "https://www.hulu.com/watch/85ffce47-28ab-42f5-8b12-b229b9a45239"
                        },
                        {
                          "package": {
                            "technicalName": "amazonhbomax"
                          },
                          "deeplinkURL": "https://watch.amazon.com/watch?gti=amzn1.dv.gti.9e016ff9-00df-4be2-a566-03efb1848340"
                        },
                        {
                          "package": {
                            "technicalName": "max"
                          },
                          "deeplinkURL": "https://play.hbomax.com/video/watch/db50969a-8890-4d4d-a653-5709ed608ce4?utm_source=universal_search"
                        },
                        {
                          "package": {
                            "technicalName": "max"
                          },
                          "deeplinkURL": "https://play.hbomax.com/video/watch/db50969a-8890-4d4d-a653-5709ed608ce4?utm_source=universal_search"
                        }
                      ]
                    },
                    {
                      "content": {
                        "seasonNumber": 2,
                        "episodeNumber": 2
                      },
                      "offers": [
                        {
                          "package": {
                            "technicalName": "hulu"
                          },
                          "deeplinkURL": "https://www.hulu.com/watch/0a627173-2db9-4030-92f8-34ab8b36da9c"
                        },
                        {
                          "package": {
                            "technicalName": "amazonhbomax"
                          },
                          "deeplinkURL": "https://watch.amazon.com/watch?gti=amzn1.dv.gti.8338caab-00df-4e04-8def-7f9af1b9cbc4"
                        },
                        {
                          "package": {
                            "technicalName": "max"
                          },
                          "deeplinkURL": "https://play.hbomax.com/video/watch/9671af7b-e60d-46bb-ac9a-bf5c25a10cac?utm_source=universal_search"
                        },
                        {
                          "package": {
                            "technicalName": "max"
                          },
                          "deeplinkURL": "https://play.hbomax.com/video/watch/9671af7b-e60d-46bb-ac9a-bf5c25a10cac?utm_source=universal_search"
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          }
        }
        """#
}
