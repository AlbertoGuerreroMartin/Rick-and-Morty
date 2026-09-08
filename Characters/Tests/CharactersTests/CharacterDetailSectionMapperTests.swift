//
//  CharacterDetailSectionMapperTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Foundation
import Testing
@testable import Characters

/// The header occupies the screen while nothing else has loaded: spinner, error with Retry, or the picture.
@Suite("CharacterDetailHeaderSectionMapper")
@MainActor
struct CharacterDetailHeaderSectionMapperTests {

    @Test("loading hides everything, whatever else is true")
    func loadingWins() {
        let mapper = makeMapper()

        #expect(mapper.mapToRenderModel(.init(isLoading: true, detail: nil, loadFailed: false)) == .hidden)
        #expect(mapper.mapToRenderModel(.init(isLoading: true, detail: .make(), loadFailed: false)) == .hidden)
        // A retry raises the spinner before clearing the failed flag.
        #expect(mapper.mapToRenderModel(.init(isLoading: true, detail: nil, loadFailed: true)) == .hidden)
    }

    @Test("a failed load draws the failure")
    func failureIsDrawn() {
        #expect(makeMapper().mapToRenderModel(.init(isLoading: false, detail: nil, loadFailed: true)) == .failed)
    }

    @Test("no character yet is hidden, not failed")
    func nilDetailIsHidden() {
        #expect(makeMapper().mapToRenderModel(.init(isLoading: false, detail: nil, loadFailed: false)) == .hidden)
    }

    @Test("a character maps to the four things the header draws")
    func detailMapsToTheHeader() {
        let detail = CharacterDetailModel.make(name: "Rick Sanchez", status: .dead, species: "Human")

        let render = makeMapper().mapToRenderModel(.init(isLoading: false, detail: detail, loadFailed: false))

        #expect(render == .visible(CharacterDetailHeaderRenderModel(
            name: "Rick Sanchez",
            image: URL(string: "https://example.com/1.jpeg")!,
            status: .dead,
            species: "Human"
        )))
    }

    /// The whole pipeline: a `combineLatest` missing one of its three publishers never emits.
    @Test("the render model arrives through the publisher")
    func theRenderModelIsPublished() async throws {
        let viewModel = StubCharacterDetailSectionViewModel()
        viewModel.detail = .make(name: "Rick Sanchez")
        let mapper = CharacterDetailHeaderSectionMapper(viewModel: viewModel)

        var received: CharacterDetailHeaderRenderState?
        let publisher: AnyPublisher<CharacterDetailHeaderRenderState, Never> = mapper.renderModelPublisher()
        let cancellable = publisher.sink { received = $0 }
        defer { cancellable.cancel() }

        for _ in 0..<10 { await Task.yield() }
        try await Task.sleep(for: .milliseconds(20))

        #expect(received == .visible(CharacterDetailHeaderRenderModel(
            name: "Rick Sanchez",
            image: URL(string: "https://example.com/1.jpeg")!,
            status: .alive,
            species: "Human"
        )))
    }

    private func makeMapper() -> CharacterDetailHeaderSectionMapper {
        CharacterDetailHeaderSectionMapper(viewModel: StubCharacterDetailSectionViewModel())
    }
}

/// The card's copy is baked in the mapper rather than interpolated in a `Text`, so these tests assert the strings.
@Suite("CharacterDetailInfoSectionMapper")
@MainActor
struct CharacterDetailInfoSectionMapperTests {

    @Test("loading hides the card")
    func loadingHidesTheCard() {
        #expect(makeMapper().mapToRenderModel(.init(isLoading: true, detail: .make())) == .hidden)
    }

    @Test("no character is no card")
    func nilDetailHidesTheCard() {
        #expect(makeMapper().mapToRenderModel(.init(isLoading: false, detail: nil)) == .hidden)
    }

    @Test("a full character draws every row, in reading order")
    func aFullCharacterDrawsEveryRow() throws {
        let detail = CharacterDetailModel.make(id: "1",
                                               status: .alive,
                                               species: "Human",
                                               type: "Parasite",
                                               gender: .male)

        let rows = try rows(for: detail)

        #expect(rows.map(\.label) == ["Status", "Species", "Type", "Gender",
                                      "Origin", "Location"])
        #expect(rows.first { $0.label == "Status" }?.value == "Alive")
        #expect(rows.first { $0.label == "Species" }?.value == "Human")
        #expect(rows.first { $0.label == "Type" }?.value == "Parasite")
        #expect(rows.first { $0.label == "Gender" }?.value == "Male")
    }

    @Test("the rows the API has nothing for are not drawn")
    func absentRowsAreDropped() throws {
        let detail = CharacterDetailModel.make(type: nil, origin: nil, location: nil)

        #expect(try rows(for: detail).map(\.label) == ["Status", "Species", "Gender"])
    }

    @Test("a place's three fields join into one line")
    func placesJoin() throws {
        let detail = CharacterDetailModel.make(
            origin: CharacterDetailPlaceModel(name: "Earth (C-137)",
                                              type: "Planet",
                                              dimension: "Dimension C-137")
        )

        #expect(try rows(for: detail).first { $0.label == "Origin" }?.value
                == "Earth (C-137) · Planet · Dimension C-137")
    }

    @Test("a place joins only what it has", arguments: [
        (CharacterDetailPlaceModel(name: "Earth", type: nil, dimension: nil), "Earth"),
        (CharacterDetailPlaceModel(name: "Earth", type: "Planet", dimension: nil), "Earth · Planet"),
        (CharacterDetailPlaceModel(name: "Earth", type: nil, dimension: "C-137"), "Earth · C-137"),
        // The API's own word for "we do not know", kept verbatim.
        (CharacterDetailPlaceModel(name: "unknown", type: nil, dimension: nil), "unknown")
    ])
    func placesJoinWhatTheyHave(place: CharacterDetailPlaceModel, expected: String) throws {
        #expect(try rows(for: .make(location: place)).first { $0.label == "Location" }?.value == expected)
    }

    /// The label doubles as the row's identity, so a duplicate would make `ForEach` drop or shuffle a row.
    @Test("every row has a distinct identity")
    func rowIdentitiesAreDistinct() throws {
        let rows = try rows(for: .make(type: "Parasite"))

        #expect(Set(rows.map(\.id)).count == rows.count)
    }

    private func rows(for detail: CharacterDetailModel) throws -> [CharacterDetailInfoRow] {
        let render = makeMapper().mapToRenderModel(.init(isLoading: false, detail: detail))
        guard case .visible(let rows) = render else {
            Issue.record("expected a visible card, got \(render)")
            return []
        }
        return rows
    }

    private func makeMapper() -> CharacterDetailInfoSectionMapper {
        CharacterDetailInfoSectionMapper(viewModel: StubCharacterDetailSectionViewModel())
    }
}

/// `.empty` distinguishes "asked and got none" from "haven't asked yet", which look identical in an empty list.
@Suite("CharacterDetailEpisodesSectionMapper")
@MainActor
struct CharacterDetailEpisodesSectionMapperTests {

    @Test("loading hides the section")
    func loadingHidesTheSection() {
        #expect(makeMapper().mapToRenderModel(.init(isLoading: true, detail: .make())) == .hidden)
    }

    @Test("no character is hidden, not empty")
    func nilDetailIsHidden() {
        #expect(makeMapper().mapToRenderModel(.init(isLoading: false, detail: nil)) == .hidden)
    }

    @Test("a character with no episodes is empty")
    func noEpisodesIsEmpty() {
        #expect(makeMapper().mapToRenderModel(.init(isLoading: false, detail: .make(episodes: []))) == .empty)
    }

    /// Already in broadcast order; the mapper does not re-sort.
    @Test("the episodes are passed through in the order they arrived")
    func episodesArePassedThrough() {
        let episodes: [CharacterDetailEpisodeModel] = [
            .make(name: "A Rickle in Time", season: 2, number: 1),
            .make(name: "Pilot", season: 1, number: 1),
            .make(name: "Lawnmower Dog", season: 1, number: 2)
        ]

        let render = makeMapper().mapToRenderModel(.init(isLoading: false, detail: .make(episodes: episodes)))

        #expect(render == .visible(episodes: episodes))
    }

    /// Pins that the mapper does not rebuild the rows and drop the link on the way.
    @Test("the HBO Max link reaches the section")
    func theLinkReachesTheSection() {
        let episodes: [CharacterDetailEpisodeModel] = [
            .make(name: "Pilot", season: 1, number: 1,
                  hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/1")),
            .make(name: "Lawnmower Dog", season: 1, number: 2)
        ]

        let render = makeMapper().mapToRenderModel(.init(isLoading: false, detail: .make(episodes: episodes)))

        guard case .visible(let mapped) = render else {
            Issue.record("expected a visible list, got \(render)")
            return
        }
        #expect(mapped.map(\.hboMaxURL?.absoluteString) == ["https://play.hbomax.com/video/watch/1", nil])
    }

    private func makeMapper() -> CharacterDetailEpisodesSectionMapper {
        CharacterDetailEpisodesSectionMapper(viewModel: StubCharacterDetailSectionViewModel())
    }
}

// MARK: - Test doubles

/// One stub for all three sections: they share one view model on the real screen.
@MainActor
final class StubCharacterDetailSectionViewModel: CharacterDetailHeaderSectionViewModelContract,
                                                 CharacterDetailInfoSectionViewModelContract,
                                                 CharacterDetailEpisodesSectionViewModelContract {
    @Published var isLoading = false
    @Published var detail: CharacterDetailModel?
    @Published var loadFailed = false

    private(set) var retryCallCount = 0

    var loadingPublisher: AnyPublisher<Bool, Never> { $isLoading.eraseToAnyPublisher() }
    var detailPublisher: AnyPublisher<CharacterDetailModel?, Never> { $detail.eraseToAnyPublisher() }
    var loadFailedPublisher: AnyPublisher<Bool, Never> { $loadFailed.eraseToAnyPublisher() }

    func retryLoad() {
        retryCallCount += 1
    }
}
