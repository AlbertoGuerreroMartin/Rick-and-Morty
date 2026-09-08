//
//  CharacterDetailModel.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// One character, with everything the detail screen shows, in domain terms.
struct CharacterDetailModel: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let status: CharacterStatus
    let species: String
    /// nil (never `""`) when the API leaves this blank.
    let type: String?
    let gender: CharacterGender
    let image: URL
    /// nil only when the API has no origin record; `"unknown"` is a real name, kept verbatim.
    let origin: CharacterDetailPlaceModel?
    let location: CharacterDetailPlaceModel?
    let episodes: [CharacterDetailEpisodeModel]

    func withEpisodes(_ episodes: [CharacterDetailEpisodeModel]) -> CharacterDetailModel {
        CharacterDetailModel(id: id,
                             name: name,
                             status: status,
                             species: species,
                             type: type,
                             gender: gender,
                             image: image,
                             origin: origin,
                             location: location,
                             episodes: episodes)
    }
}

struct CharacterDetailPlaceModel: Sendable, Hashable {
    let name: String
    let type: String?
    let dimension: String?
}

struct CharacterDetailEpisodeModel: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let airDate: String
    let code: String
    let season: Int
    let number: Int
    let hboMaxURL: URL?

    func withHBOMaxURL(_ url: URL?) -> CharacterDetailEpisodeModel {
        CharacterDetailEpisodeModel(id: id,
                                    name: name,
                                    airDate: airDate,
                                    code: code,
                                    season: season,
                                    number: number,
                                    hboMaxURL: url)
    }
}
