//
//  FileDiskStore.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import CryptoKit
import Foundation

/// ``DiskStoreContract`` backed by the filesystem, one file per key:
/// `<root>/<namespace>/<sha256(identifier)>`. Identifiers are hashed because they can contain
/// `/`, `?`, or newlines, or exceed the 255-byte name limit; the hash is one-way on purpose.
///
/// - Important: default root is under `Library/Caches` (OS-purgeable, not backed up) — correct
///   since every byte here is re-derivable from the network.
///
/// An actor: concurrent `store` calls into a fresh namespace could otherwise race on
/// `createDirectory`.
public actor FileDiskStore: DiskStoreContract {

    /// `Library/Caches/<bundle id>/Cache`, namespaced so a test host and the app don't collide.
    public static var defaultRoot: URL {
        let caches = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return caches
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "RickMorty", isDirectory: true)
            .appendingPathComponent("Cache", isDirectory: true)
    }

    private let root: URL
    private let fileManager: FileManager

    /// - Parameter root: injectable so tests get isolated directories and can run in parallel.
    public init(root: URL? = nil, fileManager: FileManager = .default) {
        self.root = root ?? FileDiskStore.defaultRoot
        self.fileManager = fileManager
    }

    // MARK: - DiskStoreContract

    public func data(for key: CacheKey) async throws -> Data? {
        try read(at: url(for: key))
    }

    public func store(_ data: Data, for key: CacheKey) async throws {
        let directory = directory(for: key.namespace)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        // `.atomic`: writes to a temp file then renames, so a crash mid-write can't truncate the entry.
        try data.write(to: url(for: key), options: .atomic)
    }

    public func remove(_ key: CacheKey) async throws {
        try delete(at: url(for: key))
    }

    public func removeAll(in namespace: String) async throws {
        try delete(at: directory(for: namespace))
    }

    public func namespaces() async throws -> [String] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }
        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map(\.lastPathComponent)
    }

    public func entries(in namespace: String) async throws -> [DiskStoreEntry] {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory(for: namespace),
            includingPropertiesForKeys: Array(keys)
        ) else {
            // An unwritten namespace is empty, not an error — callers are sweeping.
            return []
        }

        return contents.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            return DiskStoreEntry(
                fileName: url.lastPathComponent,
                size: values.fileSize ?? 0,
                modificationDate: values.contentModificationDate ?? .distantPast
            )
        }
    }

    public func data(fileNamed fileName: String, in namespace: String) async throws -> Data? {
        try read(at: directory(for: namespace).appendingPathComponent(fileName, isDirectory: false))
    }

    public func remove(fileNamed fileName: String, in namespace: String) async throws {
        try delete(at: directory(for: namespace).appendingPathComponent(fileName, isDirectory: false))
    }

    // MARK: - Filesystem

    private func read(at url: URL) throws -> Data? {
        do {
            return try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // Missing file (never written, or purged by the OS) is a miss, not a failure;
            // other errors propagate.
            return nil
        }
    }

    private func delete(at url: URL) throws {
        do {
            try fileManager.removeItem(at: url)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        }
    }

    private func directory(for namespace: String) -> URL {
        root.appendingPathComponent(fileName(for: namespace), isDirectory: true)
    }

    private func url(for key: CacheKey) -> URL {
        directory(for: key.namespace)
            .appendingPathComponent(FileDiskStore.fileName(for: key.identifier), isDirectory: false)
    }

    /// Namespaces are app-controlled and already safe, but sanitized anyway so a path separator
    /// can't escape the root.
    private func fileName(for namespace: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitised = String(namespace.unicodeScalars.filter(allowed.contains))
        return sanitised.isEmpty ? FileDiskStore.fileName(for: namespace) : sanitised
    }

    static func fileName(for identifier: String) -> String {
        SHA256.hash(data: Data(identifier.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
