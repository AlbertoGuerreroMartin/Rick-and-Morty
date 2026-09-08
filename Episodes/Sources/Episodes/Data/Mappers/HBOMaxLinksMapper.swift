//
//  HBOMaxLinksMapper.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

protocol HBOMaxLinksMapperContract: Sendable {
    func map(_ entity: JustWatchShowEntity?) -> HBOMaxLinks
}

/// Cannot fail: any unusable entry is simply skipped. Only `max` counts (`amazonhbomax` deeplinks
/// into Prime Video; legacy `hbomax` carries dead `urn:hbo:episode:` links); first usable offer wins.
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
                // Episode's own season number preferred; season node is a coarser fallback.
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

    private func hboMaxURL(in offers: [JustWatchOfferEntity]?) -> URL? {
        (offers ?? [])
            .lazy
            .filter { $0.package?.technicalName == Self.hboMaxTechnicalName }
            .compactMap { Self.normalized($0.deeplinkURL) }
            .first
    }

    /// Uses the *last* UUID in the path: marketing URLs carry two (show's, then episode's).
    /// A link with no UUID is kept verbatim; only non-URL text is dropped.
    private static func normalized(_ text: String?) -> URL? {
        guard let text, let url = URL(string: text) else { return nil }
        guard let match = url.path(percentEncoded: false).matches(of: uuid).last else { return url }
        return URL(string: watchURLPrefix + match.output)
    }
}
