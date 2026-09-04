//
//  CharactersLocalDataSourceTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation
import Networking
import Storage
import Testing
@testable import Characters

/// Run against the real `CodableCacheStore` on a real `FileDiskStore`: the thing
/// worth checking here is that an entity survives a JSON round trip through the
/// actual encoder and the actual filesystem, which a fake store would not
/// exercise at all.
@Suite("CharactersLocalDataSource")
struct CharactersLocalDataSourceTests {

    @Test("a page round trips through disk")
    func pageRoundTrip() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)
        let query = CharactersQuery(page: 1)

        try await dataSource.store(.make(names: ["Rick Sanchez", "Morty Smith"], next: 2), for: query)
        let entry = try await dataSource.charactersPage(for: query)

        #expect(entry?.value.results.map(\.name) == ["Rick Sanchez", "Morty Smith"])
        #expect(entry?.value.info.next == 2)
        #expect(entry?.isExpired == false)
    }

    @Test("a detail round trips through disk")
    func detailRoundTrip() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)
        let query = CharacterDetailQuery(id: "1")
        let rick = CharacterDetailEntity(id: "1",
                                         name: "Rick Sanchez",
                                         status: "Alive",
                                         species: "Human",
                                         type: "",
                                         gender: "Male",
                                         origin: nil,
                                         location: nil,
                                         image: URL(string: "https://example.com/rick.jpeg"),
                                         episode: [])

        try await dataSource.store(rick, for: query)

        #expect(try await dataSource.characterDetail(for: query)?.value == rick)
    }

    @Test("a page that was never stored reads as nil")
    func missingPageIsNil() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)

        #expect(try await dataSource.charactersPage(for: CharactersQuery(page: 9)) == nil)
    }

    @Test("two pages of the same query are two entries")
    func pagesGetDifferentKeys() async throws {
        // The bug this guards against is the expensive one: a single "characters"
        // key would have page 2 overwrite page 1 and serve the wrong rows.
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)

        try await dataSource.store(.make(names: ["Rick Sanchez"]), for: CharactersQuery(page: 1))
        try await dataSource.store(.make(names: ["Birdperson"]), for: CharactersQuery(page: 2))

        #expect(try await dataSource.charactersPage(for: CharactersQuery(page: 1))?
            .value.results.map(\.name) == ["Rick Sanchez"])
        #expect(try await dataSource.charactersPage(for: CharactersQuery(page: 2))?
            .value.results.map(\.name) == ["Birdperson"])
    }

    @Test("a list query and a detail query never collide")
    func listAndDetailGetDifferentKeys() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)

        try await dataSource.store(.make(names: ["Rick Sanchez"]), for: CharactersQuery(page: 1))

        #expect(try await dataSource.characterDetail(for: CharacterDetailQuery(id: "1")) == nil)
    }

    @Test("removeAll forgets every page and detail")
    func removeAllForgetsEverything() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let dataSource = makeDataSource(root: directory.url)
        let page = CharactersQuery(page: 1)
        let detail = CharacterDetailQuery(id: "1")
        try await dataSource.store(.make(names: ["Rick Sanchez"]), for: page)
        try await dataSource.store(CharacterDetailEntity(id: "1", name: "Rick Sanchez", status: "Alive",
                                                         species: "Human", type: "", gender: "Male",
                                                         origin: nil, location: nil, image: nil, episode: []),
                                   for: detail)

        try await dataSource.removeAll()

        #expect(try await dataSource.charactersPage(for: page) == nil)
        #expect(try await dataSource.characterDetail(for: detail) == nil)
    }

    private func makeDataSource(root: URL) -> CharactersLocalDataSource {
        CharactersLocalDataSource(cacheStore: CodableCacheStore(diskStore: FileDiskStore(root: root)))
    }
}

/// A unique directory per test, so the suite never reads the app's real cache
/// and tests cannot see each other's files.
struct TemporaryDirectory {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
