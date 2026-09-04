//
//  CharacterModel.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Foundation

// TODO: Set real model
struct CharacterDetailModel {
    let id: String
    let name: String
    let status: CharacterStatus?
    let species: String?
    let image: URL?
    let origin: String?
    let location: String?
    let episode: [String]
}
