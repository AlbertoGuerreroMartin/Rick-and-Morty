//
//  HBOMaxLinks.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// The join key: the one thing JustWatch's numbering and rickandmortyapi's code both agree on.
struct EpisodeNumber: Hashable, Sendable {
    let season: Int
    let number: Int
}

/// Missing is the normal case (unavailable, not yet listed, or a failed lookup), not an error.
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
