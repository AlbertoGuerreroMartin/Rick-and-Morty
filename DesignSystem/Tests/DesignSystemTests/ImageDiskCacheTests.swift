//
//  ImageDiskCacheTests.swift
//  DesignSystem
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation
import Storage
import Testing
@testable import DesignSystem

@Suite("ImageDiskCache")
struct ImageDiskCacheTests {

    @Test("round trips the encoded bytes for a URL")
    func roundTrip() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let cache = ImageDiskCache(diskStore: FileDiskStore(root: directory.url))
        let url = URL(string: "https://example.com/a.jpeg")!

        try await cache.store(Data("bytes".utf8), for: url)

        #expect(try await cache.data(for: url) == Data("bytes".utf8))
    }

    @Test("a URL that was never stored reads as nil")
    func missingURLIsNil() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let cache = ImageDiskCache(diskStore: FileDiskStore(root: directory.url))

        #expect(try await cache.data(for: URL(string: "https://example.com/absent.jpeg")!) == nil)
    }

    @Test("removeAll drops every cached image")
    func removeAllEmptiesTheNamespace() async throws {
        let directory = TemporaryDirectory()
        defer { directory.remove() }
        let disk = FileDiskStore(root: directory.url)
        let cache = ImageDiskCache(diskStore: disk)
        try await cache.store(Data("a".utf8), for: URL(string: "https://example.com/a.jpeg")!)
        try await cache.store(Data("b".utf8), for: URL(string: "https://example.com/b.jpeg")!)

        try await cache.removeAll()

        #expect(try await cache.data(for: URL(string: "https://example.com/a.jpeg")!) == nil)
        #expect(try await cache.data(for: URL(string: "https://example.com/b.jpeg")!) == nil)
        // The whole directory goes, not just the two files this test wrote.
        #expect(try await disk.entries(in: "images").isEmpty)
    }

    @Test("the size cap sweeps the oldest entries first")
    func sweepRemovesOldestEntries() async throws {
        // Dates set explicitly, not from the filesystem: real writes land in the same millisecond.
        let disk = FakeDiskStore()
        for index in 0..<10 {
            await disk.seed(
                fileName: "file-\(index)",
                size: 100,
                modificationDate: Date(timeIntervalSince1970: TimeInterval(index)),
                in: "images"
            )
        }
        // 1000 bytes vs. a 500-byte cap: sweep trims to 375 (75%), dropping the seven oldest.
        let cache = ImageDiskCache(diskStore: disk, capacity: 500)

        _ = try await cache.data(for: URL(string: "https://example.com/anything.jpeg")!)

        let remaining = await disk.fileNames(in: "images").sorted()
        #expect(remaining == ["file-7", "file-8", "file-9"])
    }

    @Test("a namespace under the cap is left alone")
    func sweepDoesNothingUnderTheCap() async throws {
        let disk = FakeDiskStore()
        for index in 0..<3 {
            await disk.seed(fileName: "file-\(index)",
                            size: 100,
                            modificationDate: Date(timeIntervalSince1970: TimeInterval(index)),
                            in: "images")
        }
        let cache = ImageDiskCache(diskStore: disk, capacity: 10_000)

        _ = try await cache.data(for: URL(string: "https://example.com/anything.jpeg")!)

        #expect(await disk.fileNames(in: "images").count == 3)
    }
}
