//
//  StubCharactersUseCase.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Foundation
@testable import Characters

/// A `final class` behind a lock rather than an actor: `CharactersUseCaseContract` must stay
/// a synchronous-to-declare `Sendable` protocol, and an actor would change the interleaving under test.
final class StubCharactersUseCase: CharactersUseCaseContract, @unchecked Sendable {
    /// Filter and page together: "page 2" only means something paired with its query.
    struct Call: Hashable, Sendable {
        let filter: CharactersFilter
        let page: Int
    }

    private let lock = NSLock()
    private var pagesByNumber: [Int: Result<CharactersPage, StubError>]
    /// Wins over `pagesByNumber`, so a test can make page 1 of a specific query answer differently.
    private var pagesByFilter: [CharactersFilter: Result<CharactersPage, StubError>] = [:]
    private var recorded: [Call] = []
    /// Held calls stay suspended and do not unblock on cancellation, so tests can inspect
    /// view model state while a fetch is deliberately kept open.
    private var heldCalls: Set<Call> = []

    init(pages: [Int: Result<CharactersPage, StubError>]) {
        self.pagesByNumber = pages
    }

    var calls: [Call] {
        lock.withLock { recorded }
    }

    var totalCallCount: Int {
        lock.withLock { recorded.count }
    }

    func callCount(for page: Int) -> Int {
        lock.withLock { recorded.filter { $0.page == page }.count }
    }

    func callCount(for call: Call) -> Int {
        lock.withLock { recorded.filter { $0 == call }.count }
    }

    func setResult(_ result: Result<CharactersPage, StubError>, for page: Int) {
        lock.withLock { pagesByNumber[page] = result }
    }

    func setResult(_ result: Result<CharactersPage, StubError>, for filter: CharactersFilter) {
        lock.withLock { pagesByFilter[filter] = result }
    }

    func hold(_ call: Call) {
        lock.withLock { _ = heldCalls.insert(call) }
    }

    func release(_ call: Call) {
        lock.withLock { _ = heldCalls.remove(call) }
    }

    /// Bounded so a test that never gets its call fails on assertions instead of hanging the suite.
    func waitUntilCalled(_ call: Call) async {
        for _ in 0..<100_000 {
            if callCount(for: call) > 0 { return }
            await Task.yield()
        }
    }

    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage {
        let call = Call(filter: filter, page: page)
        let result = lock.withLock { () -> Result<CharactersPage, StubError> in
            recorded.append(call)
            return pagesByFilter[filter] ?? pagesByNumber[page] ?? .failure(StubError())
        }

        while lock.withLock({ heldCalls.contains(call) }) {
            await Task.yield()
        }
        // Ensures concurrent callers of `loadNextPage()` are really in flight at the same time.
        await Task.yield()
        return try result.get()
    }
}
