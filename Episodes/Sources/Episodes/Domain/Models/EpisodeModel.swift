//
//  EpisodeModel.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// `code`/`season`/`number` all come from the same wire string, kept separately so the mapper
/// can group/order without re-parsing.
struct EpisodeModel: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    /// Kept as text, not `Date`: no time zone or time of day, only ever displayed or searched.
    let airDate: String
    let code: String
    let season: Int
    let number: Int
    let created: Date?
    let characters: [EpisodeCharacterModel]
    /// Lives on the model, not a separate stream: the mapper's `combineLatest` is already at
    /// Combine's 4-publisher limit. See `EpisodesUseCase`.
    let hboMaxURL: URL?

    func withHBOMaxURL(_ url: URL?) -> EpisodeModel {
        EpisodeModel(id: id,
                     name: name,
                     airDate: airDate,
                     code: code,
                     season: season,
                     number: number,
                     created: created,
                     characters: characters,
                     hboMaxURL: url)
    }
}

struct EpisodeCharacterModel: Sendable, Hashable, Identifiable {
    let id: String
    /// Never drawn (the avatar's accessibility label); unlike `id`/`image`, missing isn't fatal.
    let name: String?
    let image: URL
}
