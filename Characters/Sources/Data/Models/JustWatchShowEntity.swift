//
//  JustWatchShowEntity.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking

/// A show's seasons and episodes with JustWatch's streaming offers, as the server describes them.
/// Duplicated from the Episodes package rather than shared, to keep feature packages independent.
struct JustWatchShowEntity: Codable, Sendable, Hashable {
    let seasons: [JustWatchSeasonEntity]?
}

/// One season. `content` carries the season number as a fallback for episodes that omit it.
struct JustWatchSeasonEntity: Codable, Sendable, Hashable {
    let content: JustWatchSeasonContentEntity?
    let episodes: [JustWatchEpisodeEntity]?
}

/// JustWatch nests localized fields in `content(country:language:)`.
struct JustWatchSeasonContentEntity: Codable, Sendable, Hashable {
    let seasonNumber: Int?
}

struct JustWatchEpisodeEntity: Codable, Sendable, Hashable {
    let content: JustWatchEpisodeContentEntity?
    /// Server ignores `filter:`; filtering to HBO Max happens in the mapper.
    let offers: [JustWatchOfferEntity]?
}

struct JustWatchEpisodeContentEntity: Codable, Sendable, Hashable {
    let seasonNumber: Int?
    let episodeNumber: Int?
}

struct JustWatchOfferEntity: Codable, Sendable, Hashable {
    let package: JustWatchPackageEntity?
    /// `String`, not `URL`: one malformed link must not fail the whole show's decoding.
    let deeplinkURL: String?
}

/// `technicalName` is JustWatch's stable machine name (`max`, `netflix`), unlike the display name.
struct JustWatchPackageEntity: Codable, Sendable, Hashable {
    let technicalName: String?
}

// MARK: - Document

/// Hand-written: `@Document` can't express per-field arguments or the inline `... on Show` fragment.
extension JustWatchShowEntity: GraphQLDocumentConvertible {
    /// `depth` is ignored: pinned by observation against a server with introspection disabled.
    static func document(depth: Int) -> String {
        """
        ... on Show {
          seasons {
            content(country: $country, language: $language) {
              seasonNumber
            }
            episodes {
              content(country: $country, language: $language) {
                seasonNumber
                episodeNumber
              }
              offers(country: $country, platform: WEB) {
                package {
                  technicalName
                }
                deeplinkURL(platform: IOS)
              }
            }
          }
        }
        """
    }
}
