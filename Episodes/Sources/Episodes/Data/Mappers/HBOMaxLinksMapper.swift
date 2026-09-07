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

/// Turns JustWatch's offer tree into "season 1 episode 5 is at this URL".
///
/// **It cannot fail.** Every other mapper in this app throws, because every
/// other mapper produces something a row cannot be drawn without. This one
/// produces a *button*, and a button that does not appear is not a bug the user
/// can see — so a season with no numbers, an episode with no offers, a deeplink
/// that is not a URL and an entity that is entirely `nil` all reduce to the same
/// thing: that entry is skipped and the rest of the show maps normally. There is
/// no error type here on purpose; an unthrowable error is a `nil` with extra
/// steps.
///
/// Three rules do the actual work, and each of them exists because of something
/// the live response does:
///
/// - **Only `max`.** A single episode comes back with a dozen offers — Netflix,
///   Prime Video, Movistar — and two families that both look like HBO Max.
///   `amazonhbomax` is the channel *sold through* Prime Video and deeplinks into
///   Prime Video, and the legacy `hbomax` package still carries dead
///   `urn:hbo:episode:` links from before the rebrand. `max` is the one that
///   opens HBO Max. Filtering happens here rather than in the query because the
///   server ignores the `filter:` argument on the offers field.
/// - **First one wins.** Each `max` offer is listed twice per episode with an
///   identical URL, and an episode may legitimately appear in more than one
///   season node. Taking the first and moving on keeps the output deterministic
///   without deduplicating anything.
/// - **Normalise to the canonical link.** See `normalized(_:)`.
final class HBOMaxLinksMapper: HBOMaxLinksMapperContract {

    /// JustWatch's machine name for HBO Max itself, as opposed to the display
    /// name (localized, and already renamed once) or the packages that merely
    /// resell it.
    private static let hboMaxTechnicalName = "max"

    /// The one link shape the HBO Max app and website both understand.
    private static let watchURLPrefix = "https://play.hbomax.com/video/watch/"

    /// A canonical UUID, case-insensitive: eight-four-four-four-twelve hex
    /// digits. This is the episode's identity inside HBO Max, and the only part
    /// of a deeplink worth keeping.
    ///
    /// Computed rather than a `static let`, because `Regex` is not `Sendable`
    /// and a shared instance would be a Swift 6 error. The two ways out are a
    /// `nonisolated(unsafe)` promise this file cannot actually make — matching
    /// is not documented as thread-safe, unlike `ISO8601DateFormatter`'s — and
    /// building one per call, which is what this does. The cost is one regex per
    /// episode on a mapping that runs once a week, against a link this feature
    /// would rather drop than get wrong.
    private static var uuid: Regex<Substring> {
        /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.ignoresCase()
    }

    func map(_ entity: JustWatchShowEntity?) -> HBOMaxLinks {
        var urls: [EpisodeNumber: URL] = [:]

        for season in entity?.seasons ?? [] {
            for episode in season.episodes ?? [] {
                // The season number is read off the episode first and off its
                // season only as a fallback: an episode knows which season it is
                // in, and the season node is the coarser answer — right in every
                // observed response, but wrong for a special that a season node
                // lists out of place.
                guard let seasonNumber = episode.content?.seasonNumber ?? season.content?.seasonNumber,
                      let number = episode.content?.episodeNumber else {
                    // Nothing to key it on: an episode with no numbers cannot be
                    // joined to anything, and guessing would attach a link to
                    // the wrong row.
                    continue
                }

                let key = EpisodeNumber(season: seasonNumber, number: number)
                guard urls[key] == nil, let url = hboMaxURL(in: episode.offers) else { continue }
                urls[key] = url
            }
        }

        return HBOMaxLinks(urls: urls)
    }

    /// The first `max` offer that carries a usable link.
    ///
    /// "Usable" rather than "present": an offer whose `deeplinkURL` is missing or
    /// unparseable is stepped over rather than ending the search, so a broken
    /// first offer cannot hide a working second one.
    private func hboMaxURL(in offers: [JustWatchOfferEntity]?) -> URL? {
        (offers ?? [])
            .lazy
            .filter { $0.package?.technicalName == Self.hboMaxTechnicalName }
            .compactMap { Self.normalized($0.deeplinkURL) }
            .first
    }

    /// Rewrites a deeplink to `https://play.hbomax.com/video/watch/<uuid>`.
    ///
    /// The link JustWatch hands back is
    /// `.../video/watch/<uuid>?utm_source=universal_search` — their analytics
    /// tag, on a URL this app is about to hand to the system. Dropping it is
    /// both the polite thing to do and the reason to rebuild the URL from the
    /// UUID rather than strip one query item: the same episode is also reachable
    /// through the marketing site's much longer localized paths, and every one of
    /// those shapes carries the same UUID and reduces to the same canonical link.
    ///
    /// The *last* UUID in the path, not the first. The player link carries one,
    /// but the marketing site's path carries two — the show's, then the
    /// episode's (`/shows/rick-and-morty/s1/<show>/e1-pilot/<episode>`) — and
    /// the first of those would build a confident link to the show page instead
    /// of the episode.
    ///
    /// A link with no UUID in it is kept verbatim. It is not a shape this code
    /// understands, but it is still what JustWatch says will open the episode,
    /// and a link that might work beats no button at all. Only text that is not a
    /// URL is dropped.
    private static func normalized(_ text: String?) -> URL? {
        guard let text, let url = URL(string: text) else { return nil }
        guard let match = url.path(percentEncoded: false).matches(of: uuid).last else { return url }
        return URL(string: watchURLPrefix + match.output)
    }
}
