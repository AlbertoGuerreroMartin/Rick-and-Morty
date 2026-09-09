//
//  CharacterDetailViewTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Core
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
        await renderHeader(.hidden)
    }

    @Test("the header draws a failed load")
    func headerDrawsAFailedLoad() async {
        await renderHeader(.failed)
    }

    @Test("the header draws the character over the picture")
    func headerDrawsTheCharacter() async {
        await renderHeader(.visible(.make(name: "Rick Sanchez", status: .alive, species: "Human")))
    }

    @Test("the header draws a long name and a dead character")
    func headerDrawsAnAwkwardCharacter() async {
        await renderHeader(.visible(.make(name: "Abradolf Lincler of the Citadel of Ricks, Dimension C-137",
                                          status: .dead,
                                          species: "Unknown")))
    }

    @Test("the failed header retries through the view model")
    func retryReachesTheViewModel() async {
        let viewModel = StubCharacterDetailSectionViewModel()

        await renderHeader(.failed, viewModel: viewModel)

        viewModel.retryLoad()

        #expect(viewModel.retryCallCount == 1)
    }

    // MARK: - The info card

    @Test("the info card draws nothing before a character lands")
    func infoCardDrawsHidden() async {
        await renderInfo(.hidden)
    }

    @Test("the info card draws every row")
    func infoCardDrawsTheRows() async {
        await renderInfo(.visible(rows: [
            CharacterDetailInfoRow(label: "Status", value: "Alive"),
            CharacterDetailInfoRow(label: "Species", value: "Human"),
            CharacterDetailInfoRow(label: "Type", value: "Parasite"),
            CharacterDetailInfoRow(label: "Gender", value: "Male"),
            CharacterDetailInfoRow(label: "Origin", value: "Earth (C-137) · Planet · Dimension C-137"),
            CharacterDetailInfoRow(label: "Location", value: "Citadel of Ricks · Space station · unknown")
        ]))
    }

    @Test("the info card draws a character the API knows little about")
    func infoCardDrawsASparseCharacter() async {
        await renderInfo(.visible(rows: [
            CharacterDetailInfoRow(label: "Status", value: "Alive"),
            CharacterDetailInfoRow(label: "Species", value: "Human"),
            CharacterDetailInfoRow(label: "Gender", value: "Male")
        ]))
    }

    // MARK: - The episodes

    @Test("the episodes section draws nothing before a character lands")
    func episodesDrawHidden() async {
        await renderEpisodes(.hidden)
    }

    @Test("the episodes section draws a character with no episodes")
    func episodesDrawEmpty() async {
        await renderEpisodes(.empty)
    }

    @Test("the episodes section draws linked and unlinked rows side by side")
    func episodesDrawTheList() async {
        await renderEpisodes(.visible(episodes: [
            .make(name: "Pilot", season: 1, number: 1,
                  hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/1")),
            .make(name: "Lawnmower Dog", season: 1, number: 2),
            .make(name: "A Rickle in Time", season: 2, number: 1,
                  hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/2"))
        ]))
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

    @Test("the screen draws and loads through its scope")
    func screenDraws() async {
        let useCase = StubCharacterDetailUseCase(result: .success(.make(name: "Rick Sanchez")))
        let viewModel = CharacterDetailViewModel(id: "1", characterDetailUseCase: useCase)
        let screen = NavigationStack {
            CharacterDetailScreen(
                makeScope: {
                    let scope = DependencyContainer()
                    scope.register((any CharacterDetailViewModelContract).self) { _ in viewModel }
                    scope.register((any CharacterDetailHeaderSectionViewModelContract).self) { _ in viewModel }
                    scope.register((any CharacterDetailInfoSectionViewModelContract).self) { _ in viewModel }
                    scope.register((any CharacterDetailEpisodesSectionViewModelContract).self) { _ in viewModel }
                    scope.register((any CharacterDetailHeaderSectionMapperContract).self) { _ in
                        StubCharacterDetailHeaderSectionMapper(
                            viewModel: viewModel,
                            renderModel: .visible(.make(name: "Rick Sanchez", status: .alive, species: "Human"))
                        )
                    }
                    scope.register((any CharacterDetailInfoSectionMapperContract).self) { _ in
                        StubCharacterDetailInfoSectionMapper(viewModel: viewModel, renderModel: .hidden)
                    }
                    scope.register((any CharacterDetailEpisodesSectionMapperContract).self) { _ in
                        StubCharacterDetailEpisodesSectionMapper(viewModel: viewModel, renderModel: .empty)
                    }
                    return scope
                },
                makeSections: { scope in
                    CharacterDetailHeaderSectionView(
                        viewModel: scope.resolve((any CharacterDetailHeaderSectionViewModelContract).self),
                        renderModelPublisher: scope.resolve((any CharacterDetailHeaderSectionMapperContract).self).renderModelPublisher()
                    )
                    CharacterDetailInfoSectionView(
                        viewModel: scope.resolve((any CharacterDetailInfoSectionViewModelContract).self),
                        renderModelPublisher: scope.resolve((any CharacterDetailInfoSectionMapperContract).self).renderModelPublisher()
                    )
                    CharacterDetailEpisodesSectionView(
                        viewModel: scope.resolve((any CharacterDetailEpisodesSectionViewModelContract).self),
                        renderModelPublisher: scope.resolve((any CharacterDetailEpisodesSectionMapperContract).self).renderModelPublisher()
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
        let root = DependencyContainer()
        CharactersAssembly.register(in: root,
                                    dependencies: StubCharactersDependencies(),
                                    navigator: CharactersNavigator())

        await render(NavigationStack {
            CharacterDetailFactory.build(root: root, id: "1")
        })
    }

    // MARK: - The list and the grid, now that their rows are links

    @Test("the list section still draws with its rows as links")
    func listSectionDrawsWithLinks() async {
        let viewModel = StubCharactersSectionViewModel()
        let mapper = StubCharactersListSectionMapper(
            viewModel: viewModel,
            renderModel: .visible(characters: [.make(id: "1", name: "Rick Sanchez"),
                                               .make(id: "2", name: "Morty Smith")],
                                  footer: .none,
                                  highlight: nil)
        )

        await render(NavigationStack {
            CharactersListSectionView(viewModel: viewModel, renderModelPublisher: mapper.renderModelPublisher())
        })
    }

    @Test("the grid section still draws with its cells as links")
    func gridSectionDrawsWithLinks() async {
        let viewModel = StubCharactersSectionViewModel()
        let mapper = StubCharactersGridSectionMapper(
            viewModel: viewModel,
            renderModel: .visible(characters: [.make(id: "1", name: "Rick Sanchez"),
                                               .make(id: "2", name: "Morty Smith"),
                                               .make(id: "3", name: "Summer Smith")],
                                  footer: .none,
                                  highlight: nil)
        )

        await render(NavigationStack {
            CharactersGridSectionView(viewModel: viewModel, renderModelPublisher: mapper.renderModelPublisher())
        })
    }

    @Test("a route is identified by its character")
    func routesAreValues() {
        #expect(CharactersRoute.detail(id: "1") == CharactersRoute.detail(id: "1"))
        #expect(CharactersRoute.detail(id: "1") != CharactersRoute.detail(id: "2"))
    }

    // MARK: - Hosting

    private func renderHeader(_ renderModel: CharacterDetailHeaderRenderState,
                              viewModel: StubCharacterDetailSectionViewModel = StubCharacterDetailSectionViewModel()) async {
        await render(CharacterDetailHeaderSectionView(
            viewModel: viewModel,
            renderModelPublisher: StubCharacterDetailHeaderSectionMapper(viewModel: viewModel,
                                                                         renderModel: renderModel).renderModelPublisher()
        ))
    }

    private func renderInfo(_ renderModel: CharacterDetailInfoRenderModel) async {
        let viewModel = StubCharacterDetailSectionViewModel()
        await render(CharacterDetailInfoSectionView(
            viewModel: viewModel,
            renderModelPublisher: StubCharacterDetailInfoSectionMapper(viewModel: viewModel,
                                                                       renderModel: renderModel).renderModelPublisher()
        ))
    }

    private func renderEpisodes(_ renderModel: CharacterDetailEpisodesRenderModel) async {
        let viewModel = StubCharacterDetailSectionViewModel()
        await render(CharacterDetailEpisodesSectionView(
            viewModel: viewModel,
            renderModelPublisher: StubCharacterDetailEpisodesSectionMapper(viewModel: viewModel,
                                                                           renderModel: renderModel).renderModelPublisher()
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

private extension CharacterDetailHeaderRenderModel {
    static func make(name: String, status: CharacterStatus, species: String) -> CharacterDetailHeaderRenderModel {
        let detail = CharacterDetailModel.make(name: name, status: status, species: species)
        return CharacterDetailHeaderRenderModel(name: detail.name,
                                                image: detail.image,
                                                status: detail.status,
                                                species: detail.species)
    }
}

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
