//
//  TestDoubles.swift
//  DesignSystem
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation
import Networking
import Storage
import Synchronization
@testable import DesignSystem

/// A unique directory per test. Production's disk cache lives under a shared `Library/Caches`
/// path; a suite pointed at it would leak files and let tests see each other's entries.
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

/// A disk cache where every operation fails — a full disk, in one type.
struct FailingImageDiskCache: ImageDiskCacheContract {
    struct Failure: Error {}

    func data(for url: URL) async throws -> Data? { throw Failure() }

    func store(_ data: Data, for url: URL) async throws { throw Failure() }

    func removeAll() async throws { throw Failure() }
}

/// Records the network events an image load produced.
final class SpyAPISink: APILogSinkContract, @unchecked Sendable {
    private let storage = Mutex<[APILogEvent]>([])

    var events: [APILogEvent] {
        storage.withLock { $0 }
    }

    var requests: [APIRequestRecord] {
        events.compactMap { if case .request(let record) = $0 { record } else { nil } }
    }

    var responses: [APIResponseRecord] {
        events.compactMap { if case .response(let record) = $0 { record } else { nil } }
    }

    func log(_ event: APILogEvent) {
        storage.withLock { $0.append(event) }
    }
}

/// Records cache events an image load produced — which layer answered is otherwise invisible,
/// since every hit returns the same bitmap.
final class SpyImageCacheSink: CacheLogSinkContract, @unchecked Sendable {
    private let storage = Mutex<[CacheLogEvent]>([])

    var events: [CacheLogEvent] {
        storage.withLock { $0 }
    }

    var outcomes: [CacheLogEvent.Outcome] {
        events.map(\.outcome)
    }

    func log(_ event: CacheLogEvent) {
        storage.withLock { $0.append(event) }
    }
}

/// In-memory ``DiskStoreContract`` with entry metadata set by the test, since real files
/// written back-to-back share a timestamp and the sweep order depends on it.
actor FakeDiskStore: DiskStoreContract {
    private struct File {
        var data: Data
        var size: Int
        var modificationDate: Date
    }

    private var files: [String: [String: File]] = [:]

    func seed(fileName: String, size: Int, modificationDate: Date, in namespace: String) {
        files[namespace, default: [:]][fileName] = File(
            data: Data(repeating: 0, count: size),
            size: size,
            modificationDate: modificationDate
        )
    }

    func fileNames(in namespace: String) -> [String] {
        Array((files[namespace] ?? [:]).keys)
    }

    // MARK: - DiskStoreContract

    func data(for key: CacheKey) async throws -> Data? {
        files[key.namespace]?[key.identifier]?.data
    }

    func store(_ data: Data, for key: CacheKey) async throws {
        files[key.namespace, default: [:]][key.identifier] = File(
            data: data,
            size: data.count,
            modificationDate: Date()
        )
    }

    func remove(_ key: CacheKey) async throws {
        files[key.namespace]?.removeValue(forKey: key.identifier)
    }

    func removeAll(in namespace: String) async throws {
        files.removeValue(forKey: namespace)
    }

    func namespaces() async throws -> [String] {
        Array(files.keys)
    }

    func entries(in namespace: String) async throws -> [DiskStoreEntry] {
        (files[namespace] ?? [:]).map { name, file in
            DiskStoreEntry(fileName: name, size: file.size, modificationDate: file.modificationDate)
        }
    }

    func data(fileNamed fileName: String, in namespace: String) async throws -> Data? {
        files[namespace]?[fileName]?.data
    }

    func remove(fileNamed fileName: String, in namespace: String) async throws {
        files[namespace]?.removeValue(forKey: fileName)
    }
}
