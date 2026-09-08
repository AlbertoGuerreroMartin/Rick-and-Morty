//
//  FileDiskStoreTests.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation
import Testing
@testable import Storage

/// Every test gets its own root directory (see ``TemporaryDirectory``), so the suite can run
/// in parallel.
@Suite("FileDiskStore")
struct FileDiskStoreTests {

    @Test("round trips bytes")
    func roundTrip() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = FileDiskStore(root: directory.url)
        let key = CacheKey(namespace: "characters", identifier: "page|1")

        try await store.store(Data("morty".utf8), for: key)

        #expect(try await store.data(for: key) == Data("morty".utf8))
    }

    @Test("a key that was never written reads as nil")
    func missingKeyIsNil() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = FileDiskStore(root: directory.url)

        let data = try await store.data(for: CacheKey(namespace: "characters", identifier: "absent"))

        #expect(data == nil)
    }

    @Test("the same identifier in two namespaces is two entries")
    func namespacesAreIsolated() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = FileDiskStore(root: directory.url)
        let characters = CacheKey(namespace: "characters", identifier: "1")
        let episodes = CacheKey(namespace: "episodes", identifier: "1")

        try await store.store(Data("c".utf8), for: characters)
        try await store.store(Data("e".utf8), for: episodes)

        #expect(try await store.data(for: characters) == Data("c".utf8))
        #expect(try await store.data(for: episodes) == Data("e".utf8))
    }

    @Test("removing a key leaves its namespace siblings alone")
    func removeSingleKey() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = FileDiskStore(root: directory.url)
        let first = CacheKey(namespace: "characters", identifier: "1")
        let second = CacheKey(namespace: "characters", identifier: "2")
        try await store.store(Data("1".utf8), for: first)
        try await store.store(Data("2".utf8), for: second)

        try await store.remove(first)

        #expect(try await store.data(for: first) == nil)
        #expect(try await store.data(for: second) == Data("2".utf8))
    }

    @Test("removeAll empties one namespace and only that one")
    func removeAllInNamespace() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = FileDiskStore(root: directory.url)
        let character = CacheKey(namespace: "characters", identifier: "1")
        let episode = CacheKey(namespace: "episodes", identifier: "1")
        try await store.store(Data("c".utf8), for: character)
        try await store.store(Data("e".utf8), for: episode)

        try await store.removeAll(in: "characters")

        #expect(try await store.data(for: character) == nil)
        #expect(try await store.data(for: episode) == Data("e".utf8))
    }

    @Test("removing a namespace that was never written does not throw")
    func removeAllOnMissingNamespace() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = FileDiskStore(root: directory.url)

        try await store.removeAll(in: "never-written")
    }

    @Test("entries report one file per key, with sizes")
    func listsEntries() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = FileDiskStore(root: directory.url)
        try await store.store(Data("12345".utf8), for: CacheKey(namespace: "images", identifier: "a"))
        try await store.store(Data("678".utf8), for: CacheKey(namespace: "images", identifier: "b"))

        let entries = try await store.entries(in: "images")

        #expect(entries.count == 2)
        #expect(entries.map(\.size).sorted() == [3, 5])
    }

    @Test("a listed entry can be read back and deleted by file name")
    func readsAndRemovesListedEntry() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = FileDiskStore(root: directory.url)
        let key = CacheKey(namespace: "images", identifier: "a")
        try await store.store(Data("bytes".utf8), for: key)
        let entry = try #require(try await store.entries(in: "images").first)

        #expect(try await store.data(fileNamed: entry.fileName, in: "images") == Data("bytes".utf8))

        try await store.remove(fileNamed: entry.fileName, in: "images")

        #expect(try await store.data(for: key) == nil)
    }

    @Test("entries on a namespace that does not exist is empty, not an error")
    func entriesOnMissingNamespace() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = FileDiskStore(root: directory.url)

        #expect(try await store.entries(in: "nothing-here").isEmpty)
    }

    @Test("namespaces lists what has been written")
    func listsNamespaces() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = FileDiskStore(root: directory.url)
        try await store.store(Data("c".utf8), for: CacheKey(namespace: "characters", identifier: "1"))
        try await store.store(Data("i".utf8), for: CacheKey(namespace: "images", identifier: "1"))

        #expect(try await store.namespaces().sorted() == ["characters", "images"])
    }

    @Test("an identifier full of path characters still produces one flat file")
    func identifiersAreHashedNotPathed() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = FileDiskStore(root: directory.url)
        // A real identifier: a GraphQL document with slashes, braces and newlines.
        let key = CacheKey(namespace: "characters", identifier: "characters|{ id\nname }|../../escape")

        try await store.store(Data("ok".utf8), for: key)

        #expect(try await store.data(for: key) == Data("ok".utf8))
        #expect(try await store.entries(in: "characters").count == 1)
    }
}
