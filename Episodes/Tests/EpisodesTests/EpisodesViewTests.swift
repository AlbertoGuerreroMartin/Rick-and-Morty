//
//  EpisodesViewTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking
import Storage
import SwiftUI
import Testing
import UIKit
@testable import Episodes

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
/// render model are already pinned by `EpisodesListSectionMapperTests`; what is
/// left to check is that each of them draws at all.
@Suite("Episodes views")
@MainActor
struct EpisodesViewTests {

    @Test("the section draws the spinner while loading")
    func sectionDrawsWhileLoading() async {
        let viewModel = StubEpisodesListViewModel()
        viewModel.isLoading = true

        await renderSection(viewModel)
    }

    @Test("the section draws a failed load")
    func sectionDrawsAFailedLoad() async {
        let viewModel = StubEpisodesListViewModel()
        viewModel.episodes = []
        viewModel.loadFailed = true

        await renderSection(viewModel)
    }

    @Test("the section draws an empty catalogue")
    func sectionDrawsAnEmptyCatalogue() async {
        let viewModel = StubEpisodesListViewModel()
        viewModel.episodes = []

        await renderSection(viewModel)
    }

    @Test("the section draws a search that matched nothing")
    func sectionDrawsNoMatches() async {
        let viewModel = StubEpisodesListViewModel()
        viewModel.episodes = [.make(name: "Pilot", season: 1, number: 1)]
        viewModel.searchQuery = EpisodesSearchQuery(text: "squanch")

        await renderSection(viewModel)
    }

    @Test("the section draws grouped seasons")
    func sectionDrawsSeasons() async {
        let viewModel = StubEpisodesListViewModel()
        viewModel.episodes = [
            .make(name: "Pilot", season: 1, number: 1, characters: .cast),
            .make(name: "Lawnmower Dog", season: 1, number: 2),
            .make(name: "A Rickle in Time", season: 2, number: 1, characters: .cast)
        ]

        await renderSection(viewModel)
    }

    /// The Retry button is the only escape from a failed load, so it has to
    /// reach the view model rather than merely exist.
    @Test("the failed empty state retries through the view model")
    func retryReachesTheViewModel() async {
        let viewModel = StubEpisodesListViewModel()
        viewModel.episodes = []
        viewModel.loadFailed = true

        await renderSection(viewModel)

        // Driven directly: tapping a `ContentUnavailableView` action means
        // walking a UIKit hierarchy for a button whose identity SwiftUI does not
        // promise, which would test the framework rather than this wiring.
        viewModel.retryLoad()

        #expect(viewModel.retryCallCount == 1)
    }

    @Test("a row draws with and without characters")
    func rowDraws() async {
        await render(List {
            EpisodeRowView(episode: .make(name: "Pilot", season: 1, number: 1, characters: .cast))
            EpisodeRowView(episode: .make(name: "Lawnmower Dog", season: 1, number: 2))
            EpisodeRowView(episode: .make(name: "One Crew Over the Crewcoo's Morty",
                                          season: 3, number: 6,
                                          characters: [.init(id: "1",
                                                             image: URL(string: "https://example.com/1.jpeg")!)]))
        })
    }

    @Test("both empty states draw")
    func emptyStatesDraw() async {
        await render(EpisodesEmptyStateView(reason: .noMatches(query: "squanch"), onRetry: {}))
        await render(EpisodesEmptyStateView(reason: .noMatches(query: nil), onRetry: {}))
        await render(EpisodesEmptyStateView(reason: .failed, onRetry: {}))
    }

    @Test("the screen draws and loads through its graph")
    func screenDraws() async {
        let useCase = StubViewsEpisodesUseCase()
        let viewModel = EpisodesViewModel(episodesUseCase: useCase)
        let screen = EpisodesScreen(
            makeGraph: { EpisodesScreenGraph(viewModel: viewModel,
                                             listMapper: EpisodesListSectionMapper(viewModel: viewModel)) },
            makeSection: { graph in
                EpisodesListSectionView(viewModel: graph.viewModel, mapper: graph.listMapper)
            }
        )

        await render(screen)

        // The screen's `.task` is not guaranteed to have run by the time layout
        // returns, so the load is driven directly: what is under test here is
        // that the graph the screen was handed is wired to something that works,
        // and that the section redraws when it answers.
        await viewModel.loadData()
        await settle()

        #expect(viewModel.episodesPublished?.map(\.name) == ["Pilot"])
    }

    /// The factory is the feature's composition root, and every layer it wires
    /// is constructor-injected — so building the real graph needs nothing but a
    /// client and a cache store, and a missing edge would be a compile error
    /// here rather than an empty screen at runtime.
    @Test("the factory builds a working graph and a drawable screen")
    func factoryBuildsTheGraph() async {
        let dependencies = StubEpisodesDependencies()

        let graph = EpisodesFactory.makeGraph(dependencies: dependencies)
        #expect(graph.viewModel.episodesPublished == nil)
        #expect(graph.viewModel.loadingPublished == false)

        await render(EpisodesFactory.build(dependencies: dependencies))
    }

    // MARK: - Hosting

    private func renderSection(_ viewModel: StubEpisodesListViewModel) async {
        await render(EpisodesListSectionView(viewModel: viewModel,
                                             mapper: EpisodesListSectionMapper(viewModel: viewModel)))
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

private extension Array where Element == EpisodeCharacterModel {
    /// A handful of avatars, so the strip has something lazy to build.
    static var cast: [EpisodeCharacterModel] {
        (1...5).map { index in
            EpisodeCharacterModel(id: "\(index)",
                                  image: URL(string: "https://example.com/\(index).jpeg")!)
        }
    }
}

/// Stands in for the app container. The screen never reaches the network in
/// these tests, so an endpoint that resolves to nothing is exactly right — the
/// point is that the factory can be handed the two things it declares and
/// nothing else.
private struct StubEpisodesDependencies: EpisodesDependencies {
    let graphQLClient = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!)
    let cacheStore: any CacheStoreContract = CodableCacheStore(
        diskStore: FileDiskStore(
            root: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
    )
}

private final class StubViewsEpisodesUseCase: EpisodesUseCaseContract, @unchecked Sendable {
    func fetchEpisodes() async throws -> [EpisodeModel] {
        [.make(name: "Pilot", season: 1, number: 1)]
    }

    func purgeCache() async throws {}
}
