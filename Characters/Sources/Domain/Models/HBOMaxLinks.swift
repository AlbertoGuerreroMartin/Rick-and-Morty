//
//  HBOMaxLinks.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// Join key: JustWatch numbers episodes while rickandmortyapi codes them.
struct EpisodeNumber: Hashable, Sendable {
    let season: Int
    let number: Int
}

/// The HBO Max link per episode. Missing is normal, not an error.
struct HBOMaxLinks: Sendable, Equatable {
    private let urls: [EpisodeNumber: URL]

    static let empty = HBOMaxLinks(urls: [:])

    init(urls: [EpisodeNumber: URL]) {
        self.urls = urls
    }

    var isEmpty: Bool {
        urls.isEmpty
    }

    var count: Int {
        urls.count
    }

    func url(season: Int, number: Int) -> URL? {
        urls[EpisodeNumber(season: season, number: number)]
    }
}
