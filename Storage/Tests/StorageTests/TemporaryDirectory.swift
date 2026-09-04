//
//  TemporaryDirectory.swift
//  Storage
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation

/// A unique directory per test.
///
/// The store's default root is a real, shared path under `Library/Caches`. A
/// suite pointed at it would leak files into the host app, and — worse — tests
/// would see each other's entries and pass or fail depending on execution
/// order. A fresh UUID directory makes each test hermetic.
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
