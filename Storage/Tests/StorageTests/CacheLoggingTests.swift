//
//  CacheLoggingTests.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Synchronization
import Testing
@testable import Storage

// MARK: - Store reads

/// The outcome of a read is the whole payload of a cache log: a reader looking
/// at "why did this screen hit the network" needs to see a miss where they
/// expected a hit, and which layer answered when it was a hit.
@Suite("CodableCacheStore logging")
struct CodableCacheStoreLoggingTests {

    private struct Character: Codable, Sendable, Equatable {
        let id: String
        let name: String
    }

    private let key = CacheKey(namespace: "characters", identifier: "1")

    @Test("a read served from memory is logged as a memory hit")
    func memoryHit() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let sink = SpyCacheSink()
        let store = CodableCacheStore(diskStore: FileDiskStore(root: directory.url), logger: sink)
        try await store.store(Character(id: "1", name: "Rick"), for: key, lifetime: 60)

        // The write warms the memory layer, so this read never reaches disk.
        _ = try await store.entry(for: key, as: Character.self)

        #expect(sink.events.map(\.outcome) == [.hit(layer: .memory, isExpired: false)])
        #expect(sink.events.first?.key == key)
    }

    @Test("a read served from disk is logged as a disk hit")
    func diskHit() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let disk = FileDiskStore(root: directory.url)
        let sink = SpyCacheSink()
        // Written through a different instance, so the reader's memory layer is
        // empty — which is what a relaunch looks like.
        try await CodableCacheStore(diskStore: disk).store(Character(id: "1", name: "Rick"),
                                                           for: key, lifetime: 60)
        let store = CodableCacheStore(diskStore: disk, logger: sink)

        _ = try await store.entry(for: key, as: Character.self)

        #expect(sink.events.map(\.outcome) == [.hit(layer: .disk, isExpired: false)])
    }

    /// An expired entry is still an entry: the store hands it back and the
    /// repository decides. Logging it as a miss would hide the stale-while-error
    /// path entirely.
    @Test("an expired entry is logged as a hit that is expired")
    func expiredHit() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let clock = MutableTestClock(now: Date(timeIntervalSince1970: 1_000))
        let sink = SpyCacheSink()
        let store = CodableCacheStore(diskStore: FileDiskStore(root: directory.url),
                                      now: clock.closure,
                                      logger: sink)
        try await store.store(Character(id: "1", name: "Rick"), for: key, lifetime: 100)

        clock.set(Date(timeIntervalSince1970: 2_000))
        _ = try await store.entry(for: key, as: Character.self)

        #expect(sink.events.map(\.outcome) == [.hit(layer: .memory, isExpired: true)])
    }

    @Test("a key that was never written is logged as a miss")
    func miss() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let sink = SpyCacheSink()
        let store = CodableCacheStore(diskStore: FileDiskStore(root: directory.url), logger: sink)

        _ = try await store.entry(for: key, as: Character.self)

        #expect(sink.events.map(\.outcome) == [.miss])
        #expect(sink.events.first?.key == key)
    }

    /// A shape change reads as nothing at all, so it logs as nothing at all.
    /// The store line that preceded it is what tells the two apart in the log.
    @Test("an entry that no longer decodes is logged as a miss")
    func undecodableIsAMiss() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let disk = FileDiskStore(root: directory.url)
        let sink = SpyCacheSink()
        try await disk.store(Data("{ not the envelope we wrote last release }".utf8), for: key)
        let store = CodableCacheStore(diskStore: disk, logger: sink)

        _ = try await store.entry(for: key, as: Character.self)

        #expect(sink.events.map(\.outcome) == [.miss])
    }

    @Test("a store with no logger keeps working")
    func noOpLoggerIsTheDefault() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let store = CodableCacheStore(diskStore: FileDiskStore(root: directory.url))

        try await store.store(Character(id: "1", name: "Rick"), for: key, lifetime: 60)

        #expect(try await store.entry(for: key, as: Character.self)?.value.name == "Rick")
    }
}

// MARK: - Store

@Suite("CacheLogStore")
struct CacheLogStoreTests {
    private func makeEvent(_ identifier: String = "1") -> CacheLogEvent {
        CacheLogEvent(key: CacheKey(namespace: "characters", identifier: identifier), outcome: .miss)
    }

    @Test("keeps every event in the order it was logged")
    func keepsHistory() {
        let store = CacheLogStore()
        let first = makeEvent("1")
        let second = makeEvent("2")

        store.log(first)
        store.log(second)

        #expect(store.events == [first, second])
    }

    @Test("forwards each event to every sink, the initial ones and the added ones")
    func fansOutToSinks() {
        let initial = SpyCacheSink()
        let added = SpyCacheSink()
        let store = CacheLogStore(sinks: [initial])
        store.add(added)
        let event = makeEvent()

        store.log(event)

        #expect(initial.events == [event])
        #expect(added.events == [event])
    }

    @Test("a stream delivers events logged after subscribing, in order")
    func streamsLiveEvents() async {
        let store = CacheLogStore()
        let stream = store.stream()
        let first = makeEvent("1")
        let second = makeEvent("2")

        store.log(first)
        store.log(second)

        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == first)
        #expect(await iterator.next() == second)
    }

    @Test("removeAll drops the history but not the sinks")
    func removeAllKeepsSinks() {
        let sink = SpyCacheSink()
        let store = CacheLogStore(sinks: [sink])
        let first = makeEvent("1")
        let second = makeEvent("2")

        store.log(first)
        store.removeAll()
        store.log(second)

        #expect(store.events == [second])
        #expect(sink.events == [first, second])
    }

    /// Every avatar on screen is a cache read, so the history has to stay
    /// bounded or a scroll grows it for the life of the process.
    @Test("the history drops the oldest events past its capacity")
    func capsTheHistory() {
        let store = CacheLogStore(capacity: 3)
        let events = (0..<5).map { makeEvent("\($0)") }

        for event in events {
            store.log(event)
        }

        #expect(store.events == Array(events.suffix(3)))
    }
}

// MARK: - Formatter

/// The console format is a contract with whoever reads the Xcode console, so it
/// is asserted as a whole line rather than "contains the namespace".
@Suite("CacheLogFormatter")
struct CacheLogFormatterTests {
    private let formatter = CacheLogFormatter(timeZone: TimeZone(identifier: "UTC")!)
    /// 14:20:37.360 UTC on 2026-09-04.
    private let timestamp = Date(timeIntervalSince1970: 1_788_531_637.360)

    private func string(namespace: String,
                        identifier: String,
                        outcome: CacheLogEvent.Outcome) -> String {
        formatter.string(for: CacheLogEvent(
            timestamp: timestamp,
            key: CacheKey(namespace: namespace, identifier: identifier),
            outcome: outcome
        ))
    }

    @Test("a fresh disk hit prints its layer and its freshness")
    func freshDiskHit() {
        #expect(string(namespace: "characters",
                       identifier: #"characters|abc123|{"page":1}"#,
                       outcome: .hit(layer: .disk, isExpired: false))
                == #"🗂️ 14:20:37.360 > [Cache] HIT (fresh, disk) characters › characters|abc123|{"page":1}"#)
    }

    @Test("an expired memory hit prints as expired")
    func expiredMemoryHit() {
        #expect(string(namespace: "episodes",
                       identifier: #"episodes|def456|{"page":2}"#,
                       outcome: .hit(layer: .memory, isExpired: true))
                == #"🗂️ 14:20:37.360 > [Cache] HIT (expired, memory) episodes › episodes|def456|{"page":2}"#)
    }

    /// The identifier is printed verbatim — the on-disk name is a one-way hash,
    /// so this is the only thing that connects a line to what asked for it.
    @Test("a miss prints the key it missed on")
    func miss() {
        #expect(string(namespace: "images",
                       identifier: "https://rickandmortyapi.com/api/character/avatar/1.jpeg",
                       outcome: .miss)
                == "🗂️ 14:20:37.360 > [Cache] MISS images › https://rickandmortyapi.com/api/character/avatar/1.jpeg")
    }

    /// Nothing asserts on the output — `os.Logger` writes where a test cannot
    /// read it — but the sink still has to build its line without trapping, and
    /// the console logger is otherwise never exercised at all.
    @Test("the console logger accepts every outcome")
    func consoleLoggerRuns() {
        let logger = ConsoleCacheLogger(subsystem: "StorageTests",
                                        timeZone: TimeZone(identifier: "UTC")!)
        let key = CacheKey(namespace: "characters", identifier: "1")

        logger.log(CacheLogEvent(key: key, outcome: .hit(layer: .memory, isExpired: false)))
        logger.log(CacheLogEvent(key: key, outcome: .miss))
    }

    @Test("the no-op logger swallows events")
    func noOpLogger() {
        NoOpCacheLogger().log(CacheLogEvent(key: CacheKey(namespace: "a", identifier: "b"),
                                            outcome: .miss))
    }
}

// MARK: - Doubles

/// Records what the store told it, so a test can assert on outcomes it has no
/// other way to observe: a memory hit and a disk hit return identical values.
final class SpyCacheSink: CacheLogSinkContract, @unchecked Sendable {
    private let storage = Mutex<[CacheLogEvent]>([])

    var events: [CacheLogEvent] {
        storage.withLock { $0 }
    }

    func log(_ event: CacheLogEvent) {
        storage.withLock { $0.append(event) }
    }
}

/// A clock a test can move. `Mutex` rather than a bare `var` because the store
/// captures it as a `@Sendable` closure and may read it from any executor.
private final class MutableTestClock: Sendable {
    private let date: Mutex<Date>

    init(now: Date) {
        date = Mutex(now)
    }

    var closure: @Sendable () -> Date {
        { self.date.withLock { $0 } }
    }

    func set(_ now: Date) {
        date.withLock { $0 = now }
    }
}
