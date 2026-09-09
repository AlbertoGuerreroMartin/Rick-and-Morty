//
//  StubCharacterDetailUseCase.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
@testable import Characters

/// `final class` behind a lock, not an actor: an actor would hop isolation on
/// every call, changing the interleaving the generation test checks.
final class StubCharacterDetailUseCase: CharacterDetailUseCaseContract, @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<CharacterDetailModel, StubCharacterDetailError>
    private var fetchCount = 0
    private var ids: [String] = []
    /// Fetches held open by ordinal until the test releases them. Cancellation does not
    /// release them: the test is about what a late answer does.
    private var heldCalls: Set<Int> = []

    init(result: Result<CharacterDetailModel, StubCharacterDetailError>) {
        self.result = result
    }

    var fetchCallCount: Int { lock.withLock { fetchCount } }

    var requestedIDs: [String] { lock.withLock { ids } }

    func setResult(_ result: Result<CharacterDetailModel, StubCharacterDetailError>) {
        lock.withLock { self.result = result }
    }

    func hold(call: Int) {
        lock.withLock { _ = heldCalls.insert(call) }
    }

    func release(call: Int) {
        lock.withLock { _ = heldCalls.remove(call) }
    }

    /// Suspends until `count` fetches have been made. Bounded, so a test that never
    /// gets its call fails on assertions rather than hanging the suite.
    func waitUntilCalled(_ count: Int) async {
        for _ in 0..<100_000 {
            if fetchCallCount >= count { return }
            await Task.yield()
        }
    }

    func fetchCharacterDetail(id: String) async throws -> CharacterDetailModel {
        // Snapshotted at call time, so a held fetch answers with what was configured
        // when it started, not with what a later test line sets up.
        let (call, snapshot) = lock.withLock { () -> (Int, Result<CharacterDetailModel, StubCharacterDetailError>) in
            fetchCount += 1
            ids.append(id)
            return (fetchCount, result)
        }

        while lock.withLock({ heldCalls.contains(call) }) {
            await Task.yield()
        }
        await Task.yield()
        return try snapshot.get()
    }
}
