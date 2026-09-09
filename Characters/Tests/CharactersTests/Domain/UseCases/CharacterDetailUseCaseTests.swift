//
//  CharacterDetailUseCaseTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Characters

/// The use case joins the character and HBO Max links: a character failure throws, a links failure only costs buttons.
@Suite("CharacterDetailUseCase")
struct CharacterDetailUseCaseTests {

    @Test("fetchCharacterDetail forwards the id and returns the repository's answer")
    func fetchForwards() async throws {
        let repository = StubCharacterDetailRepository(detail: .make(name: "Rick Sanchez"))
        let useCase = CharacterDetailUseCase(repository: repository)

        #expect(try await useCase.fetchCharacterDetail(id: "42").name == "Rick Sanchez")
        #expect(await repository.requestedIDs == ["42"])
    }

    @Test("a repository failure reaches the caller")
    func fetchRethrows() async {
        let useCase = CharacterDetailUseCase(repository: StubCharacterDetailRepository(error: TestError()))

        await #expect(throws: TestError.self) {
            _ = try await useCase.fetchCharacterDetail(id: "1")
        }
    }

    // MARK: - The join

    /// Season and number: the only thing JustWatch and rickandmortyapi agree on.
    @Test("each episode gets the link for its own season and number")
    func linksAreJoinedByNumber() async throws {
        let repository = StubCharacterDetailRepository(
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

    @Test("the join leaves the rest of the character alone")
    func theJoinChangesNothingElse() async throws {
        let repository = StubCharacterDetailRepository(
            detail: .make(name: "Rick Sanchez", episodes: [.make(name: "Pilot", season: 1, number: 1)]),
            links: HBOMaxLinks(urls: [EpisodeNumber(season: 1, number: 1): URL(string: "https://play.hbomax.com/video/watch/1")!])
        )

        let detail = try await CharacterDetailUseCase(repository: repository).fetchCharacterDetail(id: "1")

        #expect(detail.name == "Rick Sanchez")
        #expect(detail.status == .alive)
        #expect(detail.origin?.name == "Earth (C-137)")
        #expect(detail.episodes.map(\.name) == ["Pilot"])
    }

    @Test("no links at all is a character with no buttons")
    func emptyLinksLeaveEveryEpisodeUnlinked() async throws {
        let repository = StubCharacterDetailRepository(
            detail: .make(episodes: [.make(name: "Pilot", season: 1, number: 1)]),
            links: .empty
        )

        let detail = try await CharacterDetailUseCase(repository: repository).fetchCharacterDetail(id: "1")

        #expect(detail.episodes.allSatisfy { $0.hboMaxURL == nil })
    }

    /// JustWatch is unofficial and can fail anytime; the character must load anyway.
    @Test("a links failure costs the buttons, not the screen")
    func aLinksFailureIsSurvivable() async throws {
        let repository = StubCharacterDetailRepository(
            detail: .make(episodes: [.make(name: "Pilot", season: 1, number: 1)]),
            linksError: TestError()
        )

        let detail = try await CharacterDetailUseCase(repository: repository).fetchCharacterDetail(id: "1")

        #expect(detail.episodes.map(\.name) == ["Pilot"])
        #expect(detail.episodes.allSatisfy { $0.hboMaxURL == nil })
    }

    @Test("a character failure still throws even when the links arrived")
    func aCharacterFailureStillThrows() async {
        let repository = StubCharacterDetailRepository(
            error: TestError(),
            links: HBOMaxLinks(urls: [EpisodeNumber(season: 1, number: 1): URL(string: "https://play.hbomax.com/video/watch/1")!])
        )

        await #expect(throws: TestError.self) {
            _ = try await CharacterDetailUseCase(repository: repository).fetchCharacterDetail(id: "1")
        }
    }

    /// Cancellation means the screen went away, not that JustWatch is down, so it is not swallowed.
    @Test("a cancelled links fetch is not treated as a missing link")
    func cancellationPropagates() async {
        let repository = StubCharacterDetailRepository(detail: .make(),
                                                       linksError: CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await CharacterDetailUseCase(repository: repository).fetchCharacterDetail(id: "1")
        }
    }

    /// The fake holds the character open until the links fetch has started, so this only passes if both overlap.
    @Test("both fetches are in flight at the same time")
    func bothFetchesRunConcurrently() async throws {
        let repository = StubCharacterDetailRepository(detail: .make(),
                                                       holdDetailUntilLinksStart: true)

        _ = try await CharacterDetailUseCase(repository: repository).fetchCharacterDetail(id: "1")

        #expect(await repository.detailCallCount == 1)
        #expect(await repository.linksCallCount == 1)
    }
}
