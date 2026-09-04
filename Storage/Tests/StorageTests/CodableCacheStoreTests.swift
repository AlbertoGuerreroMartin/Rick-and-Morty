//
//  CodableCacheStoreTests.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation
import Synchronization
import Testing
@testable import Storage

@Suite("CodableCacheStore")
struct CodableCacheStoreTests {

    private struct Character: Codable, Sendable, Equatable {
        let id: String
        let name: String
    }

    @Test("round trips a Codable value through disk")
    func roundTrip() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = CodableCacheStore(diskStore: FileDiskStore(root: directory.url))
        let key = CacheKey(namespace: "characters", identifier: "1")
        let rick = Character(id: "1", name: "Rick Sanchez")

        try await store.store(rick, for: key, lifetime: 60)
        let entry = try await store.entry(for: key, as: Character.self)

        #expect(entry?.value == rick)
        #expect(entry?.isExpired == false)
    }

    @Test("a key that was never written reads as nil")
    func missingKeyIsNil() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = CodableCacheStore(diskStore: FileDiskStore(root: directory.url))

        let entry = try await store.entry(for: CacheKey(namespace: "characters", identifier: "absent"),
                                          as: Character.self)

        #expect(entry == nil)
    }

    @Test("expiry is decided by the clock at read time, not at write time")
    func expiryFollowsTheClock() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let clock = MutableClock(now: Date(timeIntervalSince1970: 1_000))
        let store = CodableCacheStore(diskStore: FileDiskStore(root: directory.url), now: clock.closure)
        let key = CacheKey(namespace: "characters", identifier: "1")

        try await store.store(Character(id: "1", name: "Rick"), for: key, lifetime: 100)

        #expect(try await store.entry(for: key, as: Character.self)?.isExpired == false)

        // Same file, same bytes: only the clock moved past `expiresAt`.
        clock.set(Date(timeIntervalSince1970: 1_101))

        let stale = try await store.entry(for: key, as: Character.self)
        #expect(stale?.isExpired == true)
        // Still returned, so a caller can decide to render stale data.
        #expect(stale?.value.name == "Rick")
    }

    @Test("removing a key drops it from disk and memory")
    func removesKey() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = CodableCacheStore(diskStore: FileDiskStore(root: directory.url))
        let key = CacheKey(namespace: "characters", identifier: "1")
        try await store.store(Character(id: "1", name: "Rick"), for: key, lifetime: 60)

        try await store.remove(key)

        #expect(try await store.entry(for: key, as: Character.self) == nil)
    }

    @Test("removeExpired deletes only the entries whose lifetime ran out")
    func removeExpiredIsSelective() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let clock = MutableClock(now: Date(timeIntervalSince1970: 1_000))
        let store = CodableCacheStore(diskStore: FileDiskStore(root: directory.url), now: clock.closure)
        let shortLived = CacheKey(namespace: "characters", identifier: "short")
        let longLived = CacheKey(namespace: "episodes", identifier: "long")

        try await store.store(Character(id: "1", name: "Rick"), for: shortLived, lifetime: 10)
        try await store.store(Character(id: "2", name: "Morty"), for: longLived, lifetime: 10_000)

        clock.set(Date(timeIntervalSince1970: 1_100))
        try await store.removeExpired()

        #expect(try await store.entry(for: shortLived, as: Character.self) == nil)
        #expect(try await store.entry(for: longLived, as: Character.self)?.value.name == "Morty")
    }

    @Test("a corrupt entry reads as a miss and is swept away, never thrown")
    func corruptEntryIsAMiss() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let disk = FileDiskStore(root: directory.url)
        let store = CodableCacheStore(diskStore: disk)
        let key = CacheKey(namespace: "characters", identifier: "1")
        // What a schema change looks like from the reader's side.
        try await disk.store(Data("{ not the envelope we wrote last release }".utf8), for: key)

        #expect(try await store.entry(for: key, as: Character.self) == nil)
        // Removed, so the next read is a clean miss rather than the same failure.
        #expect(try await disk.data(for: key) == nil)
    }

    @Test("removeExpired leaves files it did not write alone and keeps sweeping")
    func removeExpiredIgnoresForeignFiles() async throws {
        // The disk store is shared: the image cache writes raw bytes through it
        // under its own namespace. A sweep that deleted whatever it could not
        // parse would wipe every cached image at launch.
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let disk = FileDiskStore(root: directory.url)
        let clock = MutableClock(now: Date(timeIntervalSince1970: 1_000))
        let store = CodableCacheStore(diskStore: disk, now: clock.closure)
        let foreign = CacheKey(namespace: "images", identifier: "https://example.com/1.jpeg")
        let corrupt = CacheKey(namespace: "characters", identifier: "corrupt")
        let expired = CacheKey(namespace: "characters", identifier: "expired")
        let healthy = CacheKey(namespace: "characters", identifier: "healthy")
        try await disk.store(Data("jpeg bytes".utf8), for: foreign)
        try await disk.store(Data("garbage".utf8), for: corrupt)
        try await store.store(Character(id: "0", name: "Old"), for: expired, lifetime: 10)
        try await store.store(Character(id: "1", name: "Rick"), for: healthy, lifetime: 10_000)

        clock.set(Date(timeIntervalSince1970: 1_100))
        try await store.removeExpired()

        #expect(try await disk.data(for: foreign) == Data("jpeg bytes".utf8))
        #expect(try await disk.data(for: corrupt) == Data("garbage".utf8))
        #expect(try await disk.data(for: expired) == nil)
        #expect(try await store.entry(for: healthy, as: Character.self)?.value.name == "Rick")
    }

    @Test("a value read twice in one session touches the disk once")
    func memoryLayerServesTheSecondRead() async throws {
        let disk = SpyDiskStore()
        let store = CodableCacheStore(diskStore: disk)
        let key = CacheKey(namespace: "characters", identifier: "1")
        // Seeded through the disk store directly so the first read is a genuine
        // miss in memory, the way a fresh launch sees it.
        let seeded = CodableCacheStore(diskStore: disk)
        try await seeded.store(Character(id: "1", name: "Rick"), for: key, lifetime: 60)

        _ = try await store.entry(for: key, as: Character.self)
        _ = try await store.entry(for: key, as: Character.self)

        #expect(await disk.readCount == 1)
    }

    @Test("removing a namespace drops its entries, memory copies included, and nothing else")
    func removeAllInNamespaceIsScoped() async throws {
        let disk = SpyDiskStore()
        let store = CodableCacheStore(diskStore: disk)
        let characters = CacheKey(namespace: "characters", identifier: "1")
        let episodes = CacheKey(namespace: "episodes", identifier: "1")
        try await store.store(Character(id: "1", name: "Rick"), for: characters, lifetime: 60)
        try await store.store(Character(id: "1", name: "Pilot"), for: episodes, lifetime: 60)
        // Warm the memory layer, so the assertion below proves the memory copy
        // went too and not just the file.
        _ = try await store.entry(for: characters, as: Character.self)

        try await store.removeAll(in: "characters")

        #expect(try await store.entry(for: characters, as: Character.self) == nil)
        #expect(try await disk.data(for: characters) == nil)
        #expect(try await store.entry(for: episodes, as: Character.self)?.value.name == "Pilot")
    }

    @Test("storing a value invalidates the memory copy of the previous one")
    func storeInvalidatesMemory() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = CodableCacheStore(diskStore: FileDiskStore(root: directory.url))
        let key = CacheKey(namespace: "characters", identifier: "1")

        try await store.store(Character(id: "1", name: "Rick"), for: key, lifetime: 60)
        _ = try await store.entry(for: key, as: Character.self)
        try await store.store(Character(id: "1", name: "Pickle Rick"), for: key, lifetime: 60)

        #expect(try await store.entry(for: key, as: Character.self)?.value.name == "Pickle Rick")
    }
}

/// A clock a test can move. `Mutex` rather than a bare `var` because the store
/// captures it as a `@Sendable` closure and may read it from any executor.
private final class MutableClock: Sendable {
    private let date: Mutex<Date>

    init(now: Date) {
        date = Mutex(now)
    }

    /// Captures `self` rather than the `Mutex`: a `Mutex` is non-copyable, so it
    /// cannot be captured by value in a closure.
    var closure: @Sendable () -> Date {
        { self.date.withLock { $0 } }
    }

    func set(_ new: Date) {
        date.withLock { $0 = new }
    }
}
