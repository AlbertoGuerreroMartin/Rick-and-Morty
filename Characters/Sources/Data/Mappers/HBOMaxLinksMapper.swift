//
//  HBOMaxLinksMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

protocol HBOMaxLinksMapperContract: Sendable {
    func map(_ entity: JustWatchShowEntity?) -> HBOMaxLinks
}

/// Turns JustWatch's offer tree into "season 1 episode 5 is at this URL". Never throws.
/// Only `max` is used — `amazonhbomax` deeplinks into Prime Video and `hbomax` carries dead
/// `urn:hbo:` links. Server ignores `filter:`, so filtering happens here.
final class HBOMaxLinksMapper: HBOMaxLinksMapperContract {

    private static let hboMaxTechnicalName = "max"
    private static let watchURLPrefix = "https://play.hbomax.com/video/watch/"

    /// Computed, not stored: `Regex` is not `Sendable`.
    private static var uuid: Regex<Substring> {
        /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.ignoresCase()
    }

    func map(_ entity: JustWatchShowEntity?) -> HBOMaxLinks {
        var urls: [EpisodeNumber: URL] = [:]

        for season in entity?.seasons ?? [] {
            for episode in season.episodes ?? [] {
                guard let seasonNumber = episode.content?.seasonNumber ?? season.content?.seasonNumber,
                      let number = episode.content?.episodeNumber else {
                    continue
                }

                let key = EpisodeNumber(season: seasonNumber, number: number)
                guard urls[key] == nil, let url = hboMaxURL(in: episode.offers) else { continue }
                urls[key] = url
            }
        }

        return HBOMaxLinks(urls: urls)
    }

    /// Each `max` offer appears twice per episode; the first usable one wins.
    private func hboMaxURL(in offers: [JustWatchOfferEntity]?) -> URL? {
        (offers ?? [])
            .lazy
            .filter { $0.package?.technicalName == Self.hboMaxTechnicalName }
            .compactMap { Self.normalized($0.deeplinkURL) }
            .first
    }

    /// Uses the *last* UUID in the path: marketing URLs carry two (show's, then episode's).
    private static func normalized(_ text: String?) -> URL? {
        guard let text, let url = URL(string: text) else { return nil }
        guard let match = url.path(percentEncoded: false).matches(of: uuid).last else { return url }
        return URL(string: watchURLPrefix + match.output)
    }
}
