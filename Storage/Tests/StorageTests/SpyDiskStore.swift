//
//  SpyDiskStore.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation
@testable import Storage

/// In-memory ``DiskStoreContract`` that counts reads, since a memory hit and a disk hit return
/// identical bytes — counting how often the layer underneath is asked is the only way to assert
/// the memory layer exists.
actor SpyDiskStore: DiskStoreContract {
    private(set) var readCount = 0
    private var files: [String: [String: Data]] = [:]

    func data(for key: CacheKey) async throws -> Data? {
        readCount += 1
        return files[key.namespace]?[FileDiskStore.fileName(for: key.identifier)]
    }

    func store(_ data: Data, for key: CacheKey) async throws {
        files[key.namespace, default: [:]][FileDiskStore.fileName(for: key.identifier)] = data
    }

    func remove(_ key: CacheKey) async throws {
        files[key.namespace]?.removeValue(forKey: FileDiskStore.fileName(for: key.identifier))
    }

    func removeAll(in namespace: String) async throws {
        files.removeValue(forKey: namespace)
    }

    func namespaces() async throws -> [String] {
        Array(files.keys)
    }

    func entries(in namespace: String) async throws -> [DiskStoreEntry] {
        (files[namespace] ?? [:]).map { name, data in
            DiskStoreEntry(fileName: name, size: data.count, modificationDate: .distantPast)
        }
    }

    func data(fileNamed fileName: String, in namespace: String) async throws -> Data? {
        files[namespace]?[fileName]
    }

    func remove(fileNamed fileName: String, in namespace: String) async throws {
        files[namespace]?.removeValue(forKey: fileName)
    }
}
