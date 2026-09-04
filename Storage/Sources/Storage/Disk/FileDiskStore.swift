//
//  FileDiskStore.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import CryptoKit
import Foundation

/// ``DiskStoreContract`` backed by the filesystem, one file per key:
/// `<root>/<namespace>/<sha256(identifier)>`.
///
/// Why hash the identifier instead of using it as the file name: identifiers
/// here are derived from query documents and URLs, so they contain `/`, `?`,
/// `{`, newlines and can run past the 255-byte name limit. Hashing gives a
/// fixed-length, filesystem-safe, collision-resistant name and costs a few
/// microseconds. It is one-way on purpose — nothing in this package needs to go
/// from a file back to a key.
///
/// - Important: the default root lives under `Library/Caches`, which means the
///   OS may purge it when the device is low on space and it is **not** included
///   in backups. That is the correct place for this data: every byte here is
///   re-derivable from the network, and shipping a rebuildable cache in the
///   user's iCloud backup is exactly what the "do not back up" rule exists to
///   prevent. Anything that must survive a purge does not belong in this store.
///
/// An actor: writes and directory creation are not atomic with respect to each
/// other, so two concurrent `store` calls into a fresh namespace could otherwise
/// race on `createDirectory`.
public actor FileDiskStore: DiskStoreContract {

    /// `Library/Caches/<bundle id>/Cache`. Namespaced by bundle id so a test
    /// host, an extension and the app never share a directory by accident.
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

    /// - Parameter root: injectable so every test gets its own directory and the
    ///   suites can run in parallel without stepping on each other.
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
        // `.atomic` writes to a sibling temp file and renames it into place, so a
        // crash or a kill mid-write leaves the previous entry intact instead of a
        // truncated file that would later decode as garbage.
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
            // A namespace nothing has written to yet is empty, not an error:
            // callers are sweeping, and "no files" is a valid answer.
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
            // "Never written" and "written and then purged by the OS" are the
            // same answer to a cache: a miss, not a failure. Everything else —
            // permissions, an unreadable volume — is a real problem and is
            // propagated so it does not hide behind a silent cache miss.
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

    /// Namespaces are written by this app, not derived from network data, so
    /// they are already short and safe — but a path separator in one would let a
    /// caller escape the root, so they go through the same sanitisation.
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
