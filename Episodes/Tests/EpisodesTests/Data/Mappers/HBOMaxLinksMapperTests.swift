//
//  HBOMaxLinksMapperTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Episodes

@Suite("HBOMaxLinksMapper")
struct HBOMaxLinksMapperTests {

    // MARK: - Picking the right offer

    @Test("a max offer becomes the episode's link, with the tracking parameter dropped")
    func maxOfferIsNormalized() {
        let links = HBOMaxLinksMapper().map(.make(episodes: [
            .make(season: 1, number: 1, offers: [
                .max("https://play.hbomax.com/video/watch/ef7d1c40-2ecc-471a-81a5-7fe06400240a?utm_source=universal_search")
            ])
        ]))

        #expect(links.url(season: 1, number: 1)?.absoluteString
                == "https://play.hbomax.com/video/watch/ef7d1c40-2ecc-471a-81a5-7fe06400240a")
    }

    @Test("offers from other packages are ignored", arguments: [
        ("netflix", "https://www.netflix.com/watch/80098733"),
        ("amazon", "https://app.primevideo.com/watch?gti=amzn1.dv.gti.ba209947-9c34-4dce-872a-58136180287c"),
        ("amazonhbomax", "https://app.primevideo.com/watch?gti=amzn1.dv.gti.ba209947-9c34-4dce-872a-58136180287c"),
        ("hbomax", "urn:hbo:episode:GVU2takgUQKPDwgEAAAAr"),
        ("movistar", "https://ver.movistarplus.es/watch/1")
    ])
    func otherPackagesAreIgnored(package: String, url: String) {
        let links = HBOMaxLinksMapper().map(.make(episodes: [
            .make(season: 1, number: 1, offers: [.make(package: package, url: url)])
        ]))

        #expect(links.isEmpty)
    }

    @Test("the first usable offer wins")
    func theFirstOfferWins() {
        let links = HBOMaxLinksMapper().map(.make(episodes: [
            .make(season: 1, number: 1, offers: [
                .max("https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444"),
                .max("https://play.hbomax.com/video/watch/bbbbbbbb-1111-2222-3333-444444444444")
            ])
        ]))

        #expect(links.url(season: 1, number: 1)?.absoluteString
                == "https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444")
    }

    @Test("an unusable offer is stepped over, not treated as the answer")
    func anUnusableOfferDoesNotEndTheSearch() {
        let links = HBOMaxLinksMapper().map(.make(episodes: [
            .make(season: 1, number: 1, offers: [
                .max(nil),
                .max(""),
                .max("https://play.hbomax.com/video/watch/cccccccc-1111-2222-3333-444444444444")
            ])
        ]))

        #expect(links.url(season: 1, number: 1)?.absoluteString
                == "https://play.hbomax.com/video/watch/cccccccc-1111-2222-3333-444444444444")
    }

    @Test("an episode whose only max offer has no link gets none")
    func anEmptyDeeplinkIsSkipped() {
        let links = HBOMaxLinksMapper().map(.make(episodes: [
            .make(season: 1, number: 1, offers: [.max(nil)])
        ]))

        #expect(links.isEmpty)
    }

    // MARK: - Normalising the link

    /// The real shape JustWatch returns for `GB`: two UUIDs, show's then episode's.
    @Test("a marketing-site URL is reduced to the canonical link for the episode, not the show")
    func marketingURLsAreNormalized() {
        // swiftlint:disable line_length
        let hboLink = "https://www.hbomax.com/gb/en/shows/rick-and-morty/s1/ab553cdc-e15d-4597-b65f-bec9201fd2dd/e1-pilot/ef7d1c40-2ecc-471a-81a5-7fe06400240a"
        // swiftlint:enable line_length
        let links = HBOMaxLinksMapper().map(.make(episodes: [
            .make(season: 1, number: 1, offers: [
                .max(hboLink)
            ])
        ]))

        #expect(links.url(season: 1, number: 1)?.absoluteString
                == "https://play.hbomax.com/video/watch/ef7d1c40-2ecc-471a-81a5-7fe06400240a")
    }

    @Test("an uppercase UUID is recognised")
    func uppercaseUUIDsAreRecognised() {
        let links = HBOMaxLinksMapper().map(.make(episodes: [
            .make(season: 1, number: 1, offers: [
                .max("https://play.hbomax.com/video/watch/EF7D1C40-2ECC-471A-81A5-7FE06400240A")
            ])
        ]))

        #expect(links.url(season: 1, number: 1)?.absoluteString
                == "https://play.hbomax.com/video/watch/EF7D1C40-2ECC-471A-81A5-7FE06400240A")
    }

    @Test("a UUID that is only in the query string is not the episode's identity")
    func onlyThePathIsSearched() {
        let links = HBOMaxLinksMapper().map(.make(episodes: [
            .make(season: 1, number: 1, offers: [
                .max("https://play.hbomax.com/redirect?target=ba209947-9c34-4dce-872a-58136180287c")
            ])
        ]))

        #expect(links.url(season: 1, number: 1)?.absoluteString
                == "https://play.hbomax.com/redirect?target=ba209947-9c34-4dce-872a-58136180287c")
    }

    @Test("a link with no UUID is kept verbatim")
    func linksWithoutAUUIDAreKept() {
        let links = HBOMaxLinksMapper().map(.make(episodes: [
            .make(season: 1, number: 1, offers: [.max("https://play.hbomax.com/series/rick-and-morty")])
        ]))

        #expect(links.url(season: 1, number: 1)?.absoluteString
                == "https://play.hbomax.com/series/rick-and-morty")
    }

    @Test("text that is not a URL at all is dropped")
    func unparsableLinksAreDropped() {
        let links = HBOMaxLinksMapper().map(.make(episodes: [
            .make(season: 1, number: 1, offers: [.max("")])
        ]))

        #expect(links.isEmpty)
    }

    // MARK: - Keying the episode

    @Test("episodes are keyed by their own season and number")
    func episodesAreKeyedByNumber() {
        let links = HBOMaxLinksMapper().map(.make(
            season: 1,
            episodes: [
                .make(season: 1, number: 1, offers: [.max("https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444")]),
                .make(season: 1, number: 2, offers: [.max("https://play.hbomax.com/video/watch/bbbbbbbb-1111-2222-3333-444444444444")])
            ]
        ))

        #expect(links.count == 2)
        #expect(links.url(season: 1, number: 1)?.absoluteString.contains("aaaaaaaa") == true)
        #expect(links.url(season: 1, number: 2)?.absoluteString.contains("bbbbbbbb") == true)
        #expect(links.url(season: 2, number: 1) == nil)
    }

    @Test("the episode's season number wins over the season's")
    func theEpisodeOwnsItsSeasonNumber() {
        let links = HBOMaxLinksMapper().map(.make(
            season: 9,
            episodes: [.make(season: 3, number: 7, offers: [.max("https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444")])]
        ))

        #expect(links.url(season: 3, number: 7) != nil)
        #expect(links.url(season: 9, number: 7) == nil)
    }

    @Test("the season's number is used when the episode has none")
    func theSeasonNumberIsTheFallback() {
        let links = HBOMaxLinksMapper().map(.make(
            season: 4,
            episodes: [.make(season: nil, number: 2, offers: [.max("https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444")])]
        ))

        #expect(links.url(season: 4, number: 2) != nil)
    }

    @Test("an episode with no number is skipped rather than guessed at")
    func episodesWithoutNumbersAreSkipped() {
        let links = HBOMaxLinksMapper().map(.make(
            season: nil,
            episodes: [
                .make(season: nil, number: nil, offers: [.max("https://play.hbomax.com/video/watch/aaaaaaaa-1111-2222-3333-444444444444")]),
                .make(season: 1, number: nil, offers: [.max("https://play.hbomax.com/video/watch/bbbbbbbb-1111-2222-3333-444444444444")])
            ]
        ))

        #expect(links.isEmpty)
    }

    // MARK: - Nothing at all

    @Test("a nil entity is an empty set of links, not a crash")
    func nilEntityMapsToEmpty() {
        #expect(HBOMaxLinksMapper().map(nil) == .empty)
    }

    @Test("a show with no seasons is empty")
    func nilSeasonsMapToEmpty() {
        #expect(HBOMaxLinksMapper().map(JustWatchShowEntity(seasons: nil)) == .empty)
    }

    @Test("a season with no episodes is empty")
    func nilEpisodesMapToEmpty() {
        #expect(HBOMaxLinksMapper().map(.make(episodes: nil)) == .empty)
    }

    @Test("an episode with no offers is empty")
    func nilOffersMapToEmpty() {
        #expect(HBOMaxLinksMapper().map(.make(episodes: [.make(season: 1, number: 1, offers: nil)])) == .empty)
    }

    // MARK: - The whole thing, end to end

    @Test("the trimmed live response maps to one link per episode")
    func theLiveResponseMaps() throws {
        let show = try JustWatchShowEntity.decoded(from: JustWatchShowEntity.liveUSResponse)

        let links = HBOMaxLinksMapper().map(show)

        #expect(links.count == 5)
        #expect(links.url(season: 1, number: 1)?.absoluteString
                == "https://play.hbomax.com/video/watch/ef7d1c40-2ecc-471a-81a5-7fe06400240a")
        #expect(links.url(season: 1, number: 3) != nil)
        #expect(links.url(season: 2, number: 2) != nil)
        #expect(links.url(season: 2, number: 3) == nil)
    }
}

// MARK: - Fixtures

extension JustWatchShowEntity {
    static func make(season: Int? = 1, episodes: [JustWatchEpisodeEntity]?) -> JustWatchShowEntity {
        JustWatchShowEntity(seasons: [
            JustWatchSeasonEntity(content: JustWatchSeasonContentEntity(seasonNumber: season),
                                  episodes: episodes)
        ])
    }
}

extension JustWatchEpisodeEntity {
    static func make(season: Int?, number: Int?, offers: [JustWatchOfferEntity]?) -> JustWatchEpisodeEntity {
        JustWatchEpisodeEntity(
            content: JustWatchEpisodeContentEntity(seasonNumber: season, episodeNumber: number),
            offers: offers
        )
    }
}

extension JustWatchOfferEntity {
    static func max(_ url: String?) -> JustWatchOfferEntity {
        make(package: "max", url: url)
    }

    static func make(package: String?, url: String?) -> JustWatchOfferEntity {
        JustWatchOfferEntity(package: JustWatchPackageEntity(technicalName: package), deeplinkURL: url)
    }
}
