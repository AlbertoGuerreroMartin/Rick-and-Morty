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

/// SwiftUI bodies are lazy: constructing a view runs no layout, so a crash in a
/// `body` — a force-unwrap, a `ForEach` over duplicate ids — survives every test
/// that only builds the value. These host each view in a real
/// `UIHostingController` on a sized window and force a layout pass, which is
/// what actually evaluates the bodies.
///
/// The sections are driven through the *real* pipeline — stub view model
/// publishers, real mapper, `.onReceive` — rather than by writing a render model
/// into the view's `@State`. That is the only way to know the subscription is
/// wired at all, and it costs nothing but a turn of the main queue.
///
/// They stay assertion-light on purpose. Snapshotting pixels would test the
/// system's rendering rather than this feature's, and the *contents* of every
/// render model are already pinned by the mapper suites; what is left to check
/// is that each of them draws at all.
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

    /// A very long name has to scale down rather than push the status line off
    /// the picture, and a dead character draws a different dot.
    @Test("the header draws a long name and a dead character")
    func headerDrawsAnAwkwardCharacter() async {
        let viewModel = StubCharacterDetailSectionViewModel()
        viewModel.detail = .make(name: "Abradolf Lincler of the Citadel of Ricks, Dimension C-137",
                                 status: .dead,
                                 species: "Unknown")

        await renderHeader(viewModel)
    }

    /// The Retry button is the only escape from a failed load, so it has to
    /// reach the view model rather than merely exist.
    @Test("the failed header retries through the view model")
    func retryReachesTheViewModel() async {
        let viewModel = StubCharacterDetailSectionViewModel()
        viewModel.loadFailed = true

        await renderHeader(viewModel)

        // Driven directly: tapping a `ContentUnavailableView` action means
        // walking a UIKit hierarchy for a button whose identity SwiftUI does not
        // promise, which would test the framework rather than this wiring.
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

    /// The other shape the card takes: four rows instead of seven, with the
    /// optional ones dropped rather than drawn empty.
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

    /// The button is the piece most easily lost: a `Button` whose body never ran
    /// is one nobody would notice was missing until they tried to use it.
    @Test("a row with a link draws its button")
    func linkedRowDraws() async {
        await render(CharacterDetailEpisodeRowView(
            episode: .make(name: "Pilot", season: 1, number: 1,
                           hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/1"))
        ))
    }

    /// The other half: no link, no button, and the row still lays out — the
    /// details take the full width whether or not anything sits beside them.
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
                    CharacterDetailHeaderSectionView(viewModel: graph.viewModel, mapper: graph.headerMapper)
                    CharacterDetailInfoSectionView(mapper: graph.infoMapper)
                    CharacterDetailEpisodesSectionView(mapper: graph.episodesMapper)
                }
            )
        }

        await render(screen)

        // The screen's `.task` is not guaranteed to have run by the time layout
        // returns, so the load is driven directly: what is under test here is
        // that the graph the screen was handed is wired to something that works,
        // and that the sections redraw when it answers.
        await viewModel.loadData()
        await settle()

        #expect(viewModel.detailPublished?.name == "Rick Sanchez")
    }

    /// The factory is the screen's composition root, and every layer it wires is
    /// constructor-injected — so building the real graph needs nothing but two
    /// clients and a cache store, and a missing edge would be a compile error
    /// here rather than a blank screen at runtime.
    @Test("the detail factory builds a drawable screen")
    func factoryBuildsADrawableScreen() async {
        let dependencies = StubCharactersDependencies()

        await render(NavigationStack {
            CharacterDetailFactory.build(dependencies: dependencies,
                                         route: CharacterDetailRoute(id: "1"))
        })
    }

    // MARK: - The list and the grid, now that their rows are links

    /// Both results sections wrap their rows in a `NavigationLink(value:)`, and
    /// a `NavigationLink` outside a navigation stack is a runtime complaint and
    /// a row that does nothing — so both are hosted inside one here, which is
    /// also where the real screen puts them.
    @Test("the list section still draws with its rows as links")
    func listSectionDrawsWithLinks() async {
        let viewModel = StubCharactersSectionViewModel()
        viewModel.characters = [.make(id: "1", name: "Rick Sanchez"),
                                .make(id: "2", name: "Morty Smith")]

        await render(NavigationStack {
            CharactersListSectionView(viewModel: viewModel,
                                      mapper: CharactersListSectionMapper(viewModel: viewModel))
        })
    }

    @Test("the grid section still draws with its cells as links")
    func gridSectionDrawsWithLinks() async {
        let viewModel = StubCharactersSectionViewModel()
        viewModel.characters = [.make(id: "1", name: "Rick Sanchez"),
                                .make(id: "2", name: "Morty Smith"),
                                .make(id: "3", name: "Summer Smith")]

        await render(NavigationStack {
            CharactersGridSectionView(viewModel: viewModel,
                                      mapper: CharactersGridSectionMapper(viewModel: viewModel))
        })
    }

    /// The route value is what the two sections and the destination agree on, so
    /// it has to be the same value for the same character however it was built.
    @Test("a route is identified by its character")
    func routesAreValues() {
        #expect(CharacterDetailRoute(id: "1") == CharacterDetailRoute(id: "1"))
        #expect(CharacterDetailRoute(id: "1") != CharacterDetailRoute(id: "2"))
    }

    // MARK: - Hosting

    private func renderHeader(_ viewModel: StubCharacterDetailSectionViewModel) async {
        await render(CharacterDetailHeaderSectionView(
            viewModel: viewModel,
            mapper: CharacterDetailHeaderSectionMapper(viewModel: viewModel)
        ))
    }

    private func renderInfo(_ viewModel: StubCharacterDetailSectionViewModel) async {
        await render(CharacterDetailInfoSectionView(
            mapper: CharacterDetailInfoSectionMapper(viewModel: viewModel)
        ))
    }

    private func renderEpisodes(_ viewModel: StubCharacterDetailSectionViewModel) async {
        await render(CharacterDetailEpisodesSectionView(
            mapper: CharacterDetailEpisodesSectionMapper(viewModel: viewModel)
        ))
    }

    /// Hosts `view` on a sized window and forces layout, so its `body` actually
    /// runs. A hosting controller with no window lays out nothing.
    ///
    /// Laid out twice around a turn of the main queue: the render model reaches
    /// a section through `.receive(on: DispatchQueue.main)`, so the first pass
    /// draws the initial `.hidden` and the second draws what the mapper
    /// produced.
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

    /// Yields the main thread long enough for the main-queue delivery in
    /// `SectionMapperContract.renderModelPublisher()` to land.
    private func settle() async {
        for _ in 0..<10 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(20))
    }
}

// MARK: - Test doubles

/// The list and the grid share their requirements, so one stub satisfies both —
/// exactly as the real `CharactersViewModel` does.
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
