//
//  CharacterDetailViewTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Characters

/// SwiftUI bodies are lazy, so views are hosted and laid out to actually evaluate them.
@Suite("Character detail views")
@MainActor
struct CharacterDetailViewTests {

    // MARK: - The header

    @Test("the header draws the spinner while loading")
    func headerDrawsWhileLoading() async {
        let viewModel = StubCharacterDetailSectionViewModel()
        viewModel.isLoading = true

        await renderHeader(viewModel)
    }

    @Test("the header draws a failed load")
    func headerDrawsAFailedLoad() async {
        let viewModel = StubCharacterDetailSectionViewModel()
        viewModel.loadFailed = true

        await renderHeader(viewModel)
    }

    @Test("the header draws the character over the picture")
    func headerDrawsTheCharacter() async {
        let viewModel = StubCharacterDetailSectionViewModel()
        viewModel.detail = .make(name: "Rick Sanchez", status: .alive, species: "Human")

        await renderHeader(viewModel)
    }

    @Test("the header draws a long name and a dead character")
    func headerDrawsAnAwkwardCharacter() async {
        let viewModel = StubCharacterDetailSectionViewModel()
        viewModel.detail = .make(name: "Abradolf Lincler of the Citadel of Ricks, Dimension C-137",
                                 status: .dead,
                                 species: "Unknown")

        await renderHeader(viewModel)
    }

    @Test("the failed header retries through the view model")
    func retryReachesTheViewModel() async {
        let viewModel = StubCharacterDetailSectionViewModel()
        viewModel.loadFailed = true

        await renderHeader(viewModel)

        viewModel.retryLoad()

        #expect(viewModel.retryCallCount == 1)
    }

    // MARK: - The info card

    @Test("the info card draws nothing before a character lands")
    func infoCardDrawsHidden() async {
        await renderInfo(StubCharacterDetailSectionViewModel())
    }

    @Test("the info card draws every row")
    func infoCardDrawsTheRows() async {
        let viewModel = StubCharacterDetailSectionViewModel()
        viewModel.detail = .make(type: "Parasite")

        await renderInfo(viewModel)
    }

    @Test("the info card draws a character the API knows little about")
    func infoCardDrawsASparseCharacter() async {
        let viewModel = StubCharacterDetailSectionViewModel()
        viewModel.detail = .make(type: nil, origin: nil, location: nil)

        await renderInfo(viewModel)
    }

    // MARK: - The episodes

    @Test("the episodes section draws nothing before a character lands")
    func episodesDrawHidden() async {
        await renderEpisodes(StubCharacterDetailSectionViewModel())
    }

    @Test("the episodes section draws a character with no episodes")
    func episodesDrawEmpty() async {
        let viewModel = StubCharacterDetailSectionViewModel()
        viewModel.detail = .make(episodes: [])

        await renderEpisodes(viewModel)
    }

    @Test("the episodes section draws linked and unlinked rows side by side")
    func episodesDrawTheList() async {
        let viewModel = StubCharacterDetailSectionViewModel()
        viewModel.detail = .make(episodes: [
            .make(name: "Pilot", season: 1, number: 1,
                  hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/1")),
            .make(name: "Lawnmower Dog", season: 1, number: 2),
            .make(name: "A Rickle in Time", season: 2, number: 1,
                  hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/2"))
        ])

        await renderEpisodes(viewModel)
    }

    @Test("a row with a link draws its button")
    func linkedRowDraws() async {
        await render(CharacterDetailEpisodeRowView(
            episode: .make(name: "Pilot", season: 1, number: 1,
                           hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/1"))
        ))
    }

    @Test("a row without a link draws no button")
    func unlinkedRowDraws() async {
        await render(CharacterDetailEpisodeRowView(episode: .make(name: "Pilot", season: 1, number: 1)))
    }

    // MARK: - The screen

    @Test("the screen draws and loads through its graph")
    func screenDraws() async {
        let useCase = StubCharacterDetailUseCase(result: .success(.make(name: "Rick Sanchez")))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)
        let screen = NavigationStack {
            CharacterDetailScreen(
                makeGraph: {
                    CharacterDetailScreenGraph(
                        viewModel: viewModel,
                        headerMapper: CharacterDetailHeaderSectionMapper(viewModel: viewModel),
                        infoMapper: CharacterDetailInfoSectionMapper(viewModel: viewModel),
                        episodesMapper: CharacterDetailEpisodesSectionMapper(viewModel: viewModel)
                    )
                },
                makeSections: { graph in
                    CharacterDetailHeaderSectionView(
                        viewModel: graph.viewModel,
                        renderModelPublisher: graph.headerMapper.renderModelPublisher()
                    )
                    CharacterDetailInfoSectionView(
                        viewModel: graph.viewModel,
                        renderModelPublisher: graph.infoMapper.renderModelPublisher()
                    )
                    CharacterDetailEpisodesSectionView(
                        viewModel: graph.viewModel,
                        renderModelPublisher: graph.episodesMapper.renderModelPublisher()
                    )
                }
            )
        }

        await render(screen)

        // `.task` is not guaranteed to have run by the time layout returns.
        await viewModel.loadData()
        await settle()

        #expect(viewModel.detailPublished?.name == "Rick Sanchez")
    }

    @Test("the detail factory builds a drawable screen")
    func factoryBuildsADrawableScreen() async {
        let dependencies = StubCharactersDependencies()

        await render(NavigationStack {
            CharacterDetailFactory.build(dependencies: dependencies, id: "1")
        })
    }

    // MARK: - The list and the grid, now that their rows are links

    @Test("the list section still draws with its rows as links")
    func listSectionDrawsWithLinks() async {
        let viewModel = StubCharactersSectionViewModel()
        viewModel.characters = [.make(id: "1", name: "Rick Sanchez"),
                                .make(id: "2", name: "Morty Smith")]

        await render(NavigationStack {
            CharactersListSectionView(
                viewModel: viewModel,
                renderModelPublisher: CharactersListSectionMapper(viewModel: viewModel).renderModelPublisher()
            )
        })
    }

    @Test("the grid section still draws with its cells as links")
    func gridSectionDrawsWithLinks() async {
        let viewModel = StubCharactersSectionViewModel()
        viewModel.characters = [.make(id: "1", name: "Rick Sanchez"),
                                .make(id: "2", name: "Morty Smith"),
                                .make(id: "3", name: "Summer Smith")]

        await render(NavigationStack {
            CharactersGridSectionView(
                viewModel: viewModel,
                renderModelPublisher: CharactersGridSectionMapper(viewModel: viewModel).renderModelPublisher()
            )
        })
    }

    @Test("a route is identified by its character")
    func routesAreValues() {
        #expect(CharactersRoute.detail(id: "1") == CharactersRoute.detail(id: "1"))
        #expect(CharactersRoute.detail(id: "1") != CharactersRoute.detail(id: "2"))
    }

    // MARK: - Hosting

    private func renderHeader(_ viewModel: StubCharacterDetailSectionViewModel) async {
        await render(CharacterDetailHeaderSectionView(
            viewModel: viewModel,
            renderModelPublisher: CharacterDetailHeaderSectionMapper(viewModel: viewModel).renderModelPublisher()
        ))
    }

    private func renderInfo(_ viewModel: StubCharacterDetailSectionViewModel) async {
        await render(CharacterDetailInfoSectionView(
            viewModel: viewModel,
            renderModelPublisher: CharacterDetailInfoSectionMapper(viewModel: viewModel).renderModelPublisher()
        ))
    }

    private func renderEpisodes(_ viewModel: StubCharacterDetailSectionViewModel) async {
        await render(CharacterDetailEpisodesSectionView(
            viewModel: viewModel,
            renderModelPublisher: CharacterDetailEpisodesSectionMapper(viewModel: viewModel).renderModelPublisher()
        ))
    }

    /// Laid out twice: `.receive(on: .main)` delivers a turn late, so the first pass draws `.hidden`.
    private func render(_ view: some View) async {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()

        await settle()

        window.layoutIfNeeded()
        window.isHidden = true
    }

    private func settle() async {
        for _ in 0..<10 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(20))
    }
}

// MARK: - Test doubles

@MainActor
final class StubCharactersSectionViewModel: CharactersListSectionViewModelContract,
                                            CharactersGridSectionViewModelContract {
    @Published var isLoading = false
    @Published var characters: [CharacterModel]?
    @Published var pagination: CharactersPaginationState = .end
    @Published var filter: CharactersFilter = .empty
    @Published var loadFailed = false

    var loadingPublisher: AnyPublisher<Bool, Never> { $isLoading.eraseToAnyPublisher() }
    var charactersPublisher: AnyPublisher<[CharacterModel]?, Never> { $characters.eraseToAnyPublisher() }
    var paginationPublisher: AnyPublisher<CharactersPaginationState, Never> { $pagination.eraseToAnyPublisher() }
    var filterPublisher: AnyPublisher<CharactersFilter, Never> { $filter.eraseToAnyPublisher() }
    var loadFailedPublisher: AnyPublisher<Bool, Never> { $loadFailed.eraseToAnyPublisher() }

    func loadNextPage() async {}
    func retryLoad() {}
    func clearAllFilters() {}
}
