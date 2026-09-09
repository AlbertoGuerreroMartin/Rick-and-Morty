//
//  StubLocationsUseCase.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
@testable import Locations

/// A locked `final class`, not an actor: `LocationsUseCaseContract` calls must not hop
/// isolation, or it would change the very interleaving these tests check.
final class StubLocationsUseCase: LocationsUseCaseContract, @unchecked Sendable {
    private let lock = NSLock()
    private var pages: [Int: Result<LocationsPage, any Error>]
    private var recorded: [Int] = []
    /// Keyed by page and call count (a retry of page 1 is its second call). Cancellation does
    /// not release a held call: these tests check behavior while a fetch stays open.
    private var heldCalls: Set<Held> = []

    private struct Held: Hashable {
        let page: Int
        let call: Int
    }

    init(pages: [Int: Result<LocationsPage, any Error>]) {
        self.pages = pages
    }

    var totalCallCount: Int { lock.withLock { recorded.count } }

    func callCount(for page: Int) -> Int {
        lock.withLock { recorded.filter { $0 == page }.count }
    }

    func setResult(_ result: Result<LocationsPage, any Error>, for page: Int) {
        lock.withLock { pages[page] = result }
    }

    func hold(page: Int, call: Int = 1) {
        lock.withLock { _ = heldCalls.insert(Held(page: page, call: call)) }
    }

    func release(page: Int, call: Int = 1) {
        lock.withLock { _ = heldCalls.remove(Held(page: page, call: call)) }
    }

    /// Bounded, so a test that never gets its call fails instead of hanging the suite.
    func waitUntilCalled(page: Int, times: Int = 1) async {
        for _ in 0..<100_000 {
            if callCount(for: page) >= times { return }
            await Task.yield()
        }
    }

    func fetchLocations(page: Int) async throws -> LocationsPage {
        // Snapshotted at call time so a held fetch answers with what was configured when it started.
        let (call, snapshot) = lock.withLock { () -> (Held, Result<LocationsPage, any Error>) in
            recorded.append(page)
            let call = Held(page: page, call: recorded.filter { $0 == page }.count)
            return (call, pages[page] ?? .failure(StubError()))
        }

        while lock.withLock({ heldCalls.contains(call) }) {
            await Task.yield()
        }
        await Task.yield()
        return try snapshot.get()
    }
}
