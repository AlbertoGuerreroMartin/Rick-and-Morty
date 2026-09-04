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

    @Test("the size cap sweeps the oldest entries first")
    func sweepRemovesOldestEntries() async throws {
        // Dates are set explicitly rather than taken from the filesystem: real
        // writes land in the same millisecond and their order would be a
        // coin flip.
        let disk = FakeDiskStore()
        for index in 0..<10 {
            await disk.seed(
                fileName: "file-\(index)",
                size: 100,
                modificationDate: Date(timeIntervalSince1970: TimeInterval(index)),
                in: "images"
            )
        }
        // 1000 bytes stored against a 500-byte cap: the sweep must trim to 375
        // (75% of the cap), which means dropping the seven oldest files.
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
