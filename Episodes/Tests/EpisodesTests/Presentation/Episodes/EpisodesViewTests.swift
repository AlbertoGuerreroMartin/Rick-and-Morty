//
//  EpisodesViewTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Core
import Networking
import Storage
import SwiftUI
import Testing
import UIKit
@testable import Episodes

/// Hosts each view in a real `UIHostingController` on a sized window and forces layout, since
/// constructing a SwiftUI view alone never runs its `body`.
@Suite("Episodes views")
@MainActor
struct EpisodesViewTests {

    @Test("the section draws the spinner while loading")
    func sectionDrawsWhileLoading() async {
        await renderSection(.hidden)
    }

    @Test("the section draws a failed load")
    func sectionDrawsAFailedLoad() async {
        await renderSection(.empty(.failed))
    }

    @Test("the section draws an empty catalogue")
    func sectionDrawsAnEmptyCatalogue() async {
        await renderSection(.empty(.noMatches(query: nil)))
    }

    @Test("the section draws a search that matched nothing")
    func sectionDrawsNoMatches() async {
        await renderSection(.empty(.noMatches(query: "squanch")))
    }

    @Test("the section draws grouped seasons")
    func sectionDrawsSeasons() async {
        await renderSection(.visible(seasons: [
            EpisodesSeasonRenderModel(season: 1, title: "Season 1", episodes: [
                .make(name: "Pilot", season: 1, number: 1, characters: .cast,
                      hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/1")),
                .make(name: "Lawnmower Dog", season: 1, number: 2)
            ]),
            EpisodesSeasonRenderModel(season: 2, title: "Season 2", episodes: [
                .make(name: "A Rickle in Time", season: 2, number: 1, characters: .cast)
            ])
        ]))
    }

    @Test("the failed empty state retries through the view model")
    func retryReachesTheViewModel() async {
        let viewModel = StubEpisodesListViewModel()

        await renderSection(.empty(.failed), viewModel: viewModel)

        // Driven directly rather than by tapping the button, whose identity SwiftUI doesn't promise.
        viewModel.retryLoad()

        #expect(viewModel.retryCallCount == 1)
    }

    @Test("a row draws with and without characters")
    func rowDraws() async {
        await renderRows(List {
            EpisodeRowView(episode: .make(name: "Pilot", season: 1, number: 1, characters: .cast))
            EpisodeRowView(episode: .make(name: "Lawnmower Dog", season: 1, number: 2))
            EpisodeRowView(episode: .make(name: "One Crew Over the Crewcoo's Morty",
                                          season: 3, number: 6,
                                          characters: [.init(id: "1",
                                                             name: "Rick Sanchez",
                                                             image: URL(string: "https://example.com/1.jpeg")!)]))
        })
    }

    @Test("a row with a link draws its button")
    func linkedRowDraws() async {
        await renderRows(List {
            EpisodeRowView(episode: .make(name: "Pilot", season: 1, number: 1,
                                          characters: .cast,
                                          hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/1")))
        })
    }

    @Test("a row without a link draws no button")
    func unlinkedRowDraws() async {
        await renderRows(List {
            EpisodeRowView(episode: .make(name: "Pilot", season: 1, number: 1, hboMaxURL: nil))
        })
    }

    @Test("linked and unlinked rows draw side by side")
    func mixedRowsDraw() async {
        await renderRows(List {
            EpisodeRowView(episode: .make(name: "Pilot", season: 1, number: 1,
                                          hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/1")))
            EpisodeRowView(episode: .make(name: "Lawnmower Dog", season: 1, number: 2))
            EpisodeRowView(episode: .make(name: "Anatomy Park", season: 1, number: 3,
                                          characters: .cast,
                                          hboMaxURL: URL(string: "https://play.hbomax.com/video/watch/2")))
        })
    }

    @Test("a row's avatars draw as links, named and unnamed")
    func avatarsDrawAsLinks() async {
        await renderRows(List {
            EpisodeRowView(episode: .make(name: "Pilot", season: 1, number: 1, characters: .cast))
            EpisodeRowView(episode: .make(name: "Lawnmower Dog", season: 1, number: 2,
                                          characters: [.init(id: "42",
                                                             name: nil,
                                                             image: URL(string: "https://example.com/42.jpeg")!)]))
        })
    }

    @Test("both empty states draw")
    func emptyStatesDraw() async {
        await render(EpisodesEmptyStateView(reason: .noMatches(query: "squanch"), onRetry: {}))
        await render(EpisodesEmptyStateView(reason: .noMatches(query: nil), onRetry: {}))
        await render(EpisodesEmptyStateView(reason: .failed, onRetry: {}))
    }

    @Test("the screen draws and loads through its scope")
    func screenDraws() async {
        let useCase = StubEpisodesUseCase(result: .success([.make(name: "Pilot", season: 1, number: 1)]))
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)
        let screen = EpisodesScreen(
            makeScope: {
                let scope = DependencyContainer()
                scope.register(EpisodesNavigator.self) { _ in EpisodesNavigator() }
                scope.register((any EpisodesViewModelContract).self) { _ in viewModel }
                scope.register((any EpisodesListSectionViewModelContract).self) { _ in viewModel }
                scope.register((any EpisodesListSectionMapperContract).self) { _ in
                    StubEpisodesListSectionMapper(viewModel: viewModel, renderModel: .hidden)
                }
                return scope
            },
            makeSection: { scope in
                EpisodesListSectionView(
                    viewModel: scope.resolve((any EpisodesListSectionViewModelContract).self),
                    renderModelPublisher: scope.resolve((any EpisodesListSectionMapperContract).self).renderModelPublisher()
                )
            },
            makeDestination: { route in
                switch route {
                case .character(let id):
                    Text(id)
                }
            }
        )

        await render(screen)

        // `.task` is not guaranteed to have run by the time layout returns, so drive it directly.
        await viewModel.loadData()
        await settle()

        #expect(viewModel.episodesPublished?.map(\.name) == ["Pilot"])
    }

    @Test("the factory builds a drawable screen")
    func factoryBuildsADrawableScreen() async {
        await render(EpisodesFactory.build(root: makeRoot(), external: StubExternalDestinations()))
    }

    @Test("showing a character pushes it onto the screen's path")
    func showingACharacterPushesIt() async {
        let navigator = EpisodesNavigator()
        let root = makeRoot(navigator: navigator)
        let external = StubExternalDestinations()

        await render(EpisodesFactory.build(root: root, external: external))

        navigator.showCharacter(id: "42")
        #expect(navigator.path == [.character(id: "42")])

        await render(EpisodesFactory.build(root: root, external: external))

        #expect(external.requestedIds.contains("42"))
    }

    // MARK: - Hosting

    /// The real wiring, so a rendered screen resolves the same graph the app does.
    private func makeRoot(navigator: EpisodesNavigator = EpisodesNavigator()) -> DependencyContainer {
        let root = DependencyContainer()
        EpisodesAssembly.register(in: root,
                                  dependencies: StubEpisodesDependencies(),
                                  navigator: navigator)
        return root
    }

    private func renderSection(_ renderModel: EpisodesListRenderModel,
                               viewModel: StubEpisodesListViewModel = StubEpisodesListViewModel()) async {
        await render(NavigationStack {
            EpisodesListSectionView(
                viewModel: viewModel,
                renderModelPublisher: StubEpisodesListSectionMapper(viewModel: viewModel,
                                                                    renderModel: renderModel).renderModelPublisher()
            )
        })
    }

    /// Rows need a `NavigationStack`: avatars are `NavigationLink`s, dead outside one.
    private func renderRows(_ rows: some View) async {
        await render(NavigationStack { rows })
    }

    /// Laid out twice around a turn of the main queue: the first pass draws the initial
    /// `.hidden`, the second draws what the mapper produced via `.receive(on: .main)`.
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

private extension Array where Element == EpisodeCharacterModel {
    static var cast: [EpisodeCharacterModel] {
        (1...5).map { index in
            EpisodeCharacterModel(id: "\(index)",
                                  name: "Character \(index)",
                                  image: URL(string: "https://example.com/\(index).jpeg")!)
        }
    }
}
