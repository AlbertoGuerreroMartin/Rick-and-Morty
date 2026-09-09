//
//  StubEpisodesUseCase.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
@testable import Episodes

/// Lock-based, not an actor: an actor would hop isolation on every call, changing the
/// interleaving the generation test checks.
final class StubEpisodesUseCase: EpisodesUseCaseContract, @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<[EpisodeModel], StubError>
    private var fetchCount = 0
    /// Fetches held open until released, by ordinal. Cancellation does not release them: the
    /// test is about what a late answer does.
    private var heldCalls: Set<Int> = []

    init(result: Result<[EpisodeModel], StubError>) {
        self.result = result
    }

    var fetchCallCount: Int { lock.withLock { fetchCount } }

    func setResult(_ result: Result<[EpisodeModel], StubError>) {
        lock.withLock { self.result = result }
    }

    func hold(call: Int) {
        lock.withLock { _ = heldCalls.insert(call) }
    }

    func release(call: Int) {
        lock.withLock { _ = heldCalls.remove(call) }
    }

    /// Bounded, so a test that never gets its call fails rather than hanging the suite.
    func waitUntilCalled(_ count: Int) async {
        for _ in 0..<100_000 {
            if fetchCallCount >= count { return }
            await Task.yield()
        }
    }

    func fetchEpisodes() async throws -> [EpisodeModel] {
        let (call, snapshot) = lock.withLock { () -> (Int, Result<[EpisodeModel], StubError>) in
            fetchCount += 1
            return (fetchCount, result)
        }

        while lock.withLock({ heldCalls.contains(call) }) {
            await Task.yield()
        }
        await Task.yield()
        return try snapshot.get()
    }
}
