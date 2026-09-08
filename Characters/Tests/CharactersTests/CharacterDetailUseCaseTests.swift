//
//  CharacterDetailUseCaseTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Characters

/// The use case is where the character and the HBO Max links become one set of
/// rows, so these tests are that join: what it matches on, what it does when
/// only one of the two answers arrives, and that it asks for both at once.
///
/// The asymmetry between the two failures is the point of most of them. A
/// character that will not load is the screen; links that will not load are a
/// missing button, and an unofficial third-party endpoint must never be able to
/// take the screen down with it.
@Suite("CharacterDetailUseCase")
struct CharacterDetailUseCaseTests {

    @Test("fetchCharacterDetail forwards the id and returns the repository's answer")
    func fetchForwards() async throws {
        let repository = FakeCharacterDetailRepository(detail: .make(name: "Rick Sanchez"))
        let useCase = CharacterDetailUseCase(repository: repository)

        #expect(try await useCase.fetchCharacterDetail(id: "42").name == "Rick Sanchez")
        #expect(await repository.requestedIDs == ["42"])
    }

    /// The character *is* the screen, so its failure is the one thing here that
    /// still throws.
    @Test("a repository failure reaches the caller")
    func fetchRethrows() async {
        let useCase = CharacterDetailUseCase(repository: FakeCharacterDetailRepository(error: TestError()))

        await #expect(throws: TestError.self) {
            _ = try await useCase.fetchCharacterDetail(id: "1")
        }
    }

    // MARK: - The join

    /// Season and number, because they are the only thing the two services
    /// agree on: JustWatch numbers episodes and rickandmortyapi codes them.
    @Test("each episode gets the link for its own season and number")
    func linksAreJoinedByNumber() async throws {
        let repository = FakeCharacterDetailRepository(
            detail: .make(episodes: [.make(name: "Pilot", season: 1, number: 1),
                                     .make(name: "Lawnmower Dog", season: 1, number: 2),
                                     .make(name: "A Rickle in Time", season: 2, number: 1)]),
            links: HBOMaxLinks(urls: [
                EpisodeNumber(season: 1, number: 1): URL(string: "https://play.hbomax.com/video/watch/1")!,
                EpisodeNumber(season: 2, number: 1): URL(string: "https://play.hbomax.com/video/watch/2")!
            ])
        )

        let detail = try await CharacterDetailUseCase(repository: repository).fetchCharacterDetail(id: "1")

        #expect(detail.episodes.map(\.hboMaxURL?.absoluteString) == [
            "https://play.hbomax.com/video/watch/1",
            nil,
            "https://play.hbomax.com/video/watch/2"
        ])
    }

    /// Everything else about the character is untouched by the join: the links
    /// only ever attach a URL to a row.
    @Test("the join leaves the rest of the character alone")
    func theJoinChangesNothingElse() async throws {
        let repository = FakeCharacterDetailRepository(
            detail: .make(name: "Rick Sanchez", episodes: [.make(name: "Pilot", season: 1, number: 1)]),
            links: HBOMaxLinks(urls: [EpisodeNumber(season: 1, number: 1): URL(string: "https://play.hbomax.com/video/watch/1")!])
        )

        let detail = try await CharacterDetailUseCase(repository: repository).fetchCharacterDetail(id: "1")

        #expect(detail.name == "Rick Sanchez")
        #expect(detail.status == .alive)
        #expect(detail.origin?.name == "Earth (C-137)")
        #expect(detail.episodes.map(\.name) == ["Pilot"])
    }

    /// An episode HBO Max does not carry is not an error and not a special case:
    /// it is simply a row with no button, which is also what every row looks
    /// like when the lookup returns nothing at all.
    @Test("no links at all is a character with no buttons")
    func emptyLinksLeaveEveryEpisodeUnlinked() async throws {
        let repository = FakeCharacterDetailRepository(
            detail: .make(episodes: [.make(name: "Pilot", season: 1, number: 1)]),
            links: .empty
        )

        let detail = try await CharacterDetailUseCase(repository: repository).fetchCharacterDetail(id: "1")

        #expect(detail.episodes.allSatisfy { $0.hboMaxURL == nil })
    }

    /// The whole reason the two fetches are separate calls: JustWatch is
    /// unofficial and can fail at any time, and the character must load anyway.
    @Test("a links failure costs the buttons, not the screen")
    func aLinksFailureIsSurvivable() async throws {
        let repository = FakeCharacterDetailRepository(
            detail: .make(episodes: [.make(name: "Pilot", season: 1, number: 1)]),
            linksError: TestError()
        )

        let detail = try await CharacterDetailUseCase(repository: repository).fetchCharacterDetail(id: "1")

        #expect(detail.episodes.map(\.name) == ["Pilot"])
        #expect(detail.episodes.allSatisfy { $0.hboMaxURL == nil })
    }

    /// The other half of that asymmetry: the character is the screen, so its
    /// failure still throws even when the links came back perfectly well.
    @Test("a character failure still throws even when the links arrived")
    func aCharacterFailureStillThrows() async {
        let repository = FakeCharacterDetailRepository(
            error: TestError(),
            links: HBOMaxLinks(urls: [EpisodeNumber(season: 1, number: 1): URL(string: "https://play.hbomax.com/video/watch/1")!])
        )

        await #expect(throws: TestError.self) {
            _ = try await CharacterDetailUseCase(repository: repository).fetchCharacterDetail(id: "1")
        }
    }

    /// Cancellation means the screen went away rather than that JustWatch is
    /// down, so it is the one links failure that is not swallowed — a task that
    /// answered anyway would defeat structured concurrency.
    @Test("a cancelled links fetch is not treated as a missing link")
    func cancellationPropagates() async {
        let repository = FakeCharacterDetailRepository(detail: .make(),
                                                       linksError: CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await CharacterDetailUseCase(repository: repository).fetchCharacterDetail(id: "1")
        }
    }

    /// Sequential fetches would add JustWatch's latency to a load the user is
    /// watching a spinner through, for two answers that need nothing from each
    /// other. The fake holds the character open until the links fetch has
    /// started, so this can only finish if both are in flight at once.
    @Test("both fetches are in flight at the same time")
    func bothFetchesRunConcurrently() async throws {
        let repository = FakeCharacterDetailRepository(detail: .make(),
                                                       holdDetailUntilLinksStart: true)

        _ = try await CharacterDetailUseCase(repository: repository).fetchCharacterDetail(id: "1")

        #expect(await repository.detailCallCount == 1)
        #expect(await repository.linksCallCount == 1)
    }
}

private actor FakeCharacterDetailRepository: CharactersRepositoryContract {
    private let detail: CharacterDetailModel?
    private let error: (any Error)?
    private let links: HBOMaxLinks
    private let linksError: (any Error)?
    /// Makes the two calls prove they overlap: the character cannot finish until
    /// the links fetch has been entered, which a sequential use case would never
    /// allow. Bounded, so a use case that stopped fetching both fails on the
    /// assertions rather than hanging the suite.
    private let holdDetailUntilLinksStart: Bool
    private(set) var detailCallCount = 0
    private(set) var linksCallCount = 0
    private(set) var requestedIDs: [String] = []

    init(detail: CharacterDetailModel? = nil,
         error: (any Error)? = nil,
         links: HBOMaxLinks = .empty,
         linksError: (any Error)? = nil,
         holdDetailUntilLinksStart: Bool = false) {
        self.detail = detail
        self.error = error
        self.links = links
        self.linksError = linksError
        self.holdDetailUntilLinksStart = holdDetailUntilLinksStart
    }

    /// Not exercised here: the list has its own suite, and this fake exists to
    /// stand under the detail use case alone.
    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage {
        throw TestError()
    }

    func fetchCharacterDetail(id: String) async throws -> CharacterDetailModel {
        detailCallCount += 1
        requestedIDs.append(id)

        if holdDetailUntilLinksStart {
            for _ in 0..<10_000 {
                if linksCallCount > 0 { break }
                // An actor is reentrant, so suspending here lets the links call
                // in — which is exactly what is being asserted.
                await Task.yield()
            }
        }

        if let error { throw error }
        guard let detail else { throw TestError() }
        return detail
    }

    func fetchHBOMaxLinks() async throws -> HBOMaxLinks {
        linksCallCount += 1
        if let linksError { throw linksError }
        return links
    }
}
