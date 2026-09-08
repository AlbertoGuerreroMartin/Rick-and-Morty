//
//  JustWatchShowEntity.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Networking

/// JustWatch's offer tree, as that server describes it. Every property is optional: this endpoint
/// is unofficial, so a shape change should cost a missing play button, not a decoding failure.
struct JustWatchShowEntity: Codable, Sendable, Hashable {
    let seasons: [JustWatchSeasonEntity]?
}

/// `content` carries the season number as a fallback for episodes that do not repeat it.
struct JustWatchSeasonEntity: Codable, Sendable, Hashable {
    let content: JustWatchSeasonContentEntity?
    let episodes: [JustWatchEpisodeEntity]?
}

/// JustWatch nests localized fields under `content(country:language:)`.
struct JustWatchSeasonContentEntity: Codable, Sendable, Hashable {
    let seasonNumber: Int?
}

struct JustWatchEpisodeEntity: Codable, Sendable, Hashable {
    let content: JustWatchEpisodeContentEntity?
    /// Server ignores the `filter:` argument on this field; filtering to HBO Max is the mapper's job.
    let offers: [JustWatchOfferEntity]?
}

struct JustWatchEpisodeContentEntity: Codable, Sendable, Hashable {
    let seasonNumber: Int?
    let episodeNumber: Int?
}

struct JustWatchOfferEntity: Codable, Sendable, Hashable {
    let package: JustWatchPackageEntity?
    /// `String?`, not `URL?`: a malformed link must not fail decoding for the whole show.
    let deeplinkURL: String?
}

/// `technicalName` is JustWatch's stable machine name (`max`, `netflix`, `amazon`).
struct JustWatchPackageEntity: Codable, Sendable, Hashable {
    let technicalName: String?
}

// MARK: - Document

/// Written by hand, not `@Document`: three fields take arguments and the root is an inline
/// fragment (`... on Show`), which the macro cannot express.
extension JustWatchShowEntity: GraphQLDocumentConvertible {
    /// `depth` is ignored: this shape is pinned by observation, nothing to expand.
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
