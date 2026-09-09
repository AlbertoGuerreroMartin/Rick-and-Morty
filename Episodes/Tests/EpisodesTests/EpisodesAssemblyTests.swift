//
//  EpisodesAssemblyTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Core
import Foundation
import Networking
import Storage
import Testing
@testable import Episodes

@Suite("EpisodesAssembly")
@MainActor
struct EpisodesAssemblyTests {

    @Test("a screen scope resolves every registration in its initial state")
    func aScopeResolvesEverything() {
        let navigator = EpisodesNavigator()
        let scope = makeRoot(navigator: navigator).makeChild()

        // Nothing is built until it is asked for, so every registration is exercised here.
        scope.resolveAll()

        #expect(scope.resolve((any EpisodesUseCaseContract).self) is EpisodesUseCase)
        #expect(scope.resolve((any EpisodesRepositoryContract).self) is EpisodesRepository)
        // Passed through, not rebuilt: the scope must hand the screen this exact instance.
        #expect(scope.resolve(EpisodesNavigator.self) === navigator)
        #expect(scope.resolve(EpisodesNavigator.self).path.isEmpty)

        let viewModel = scope.resolve(EpisodesViewModel.self)
        #expect(viewModel.episodesPublished == nil)
        #expect(viewModel.loadingPublished == false)
        // The section resolves its contract; it must land on the same instance.
        #expect(scope.resolve((any EpisodesListSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve(EpisodesListSectionMapper.self).viewModel as AnyObject === viewModel)
    }

    @Test("the data layer is shared by every screen scope")
    func theDataLayerIsShared() {
        let root = makeRoot()

        let first = root.makeChild().resolve((any EpisodesRepositoryContract).self)
        let second = root.makeChild().resolve((any EpisodesRepositoryContract).self)

        #expect(first as AnyObject === second as AnyObject)
    }

    @Test("each screen scope gets its own view model")
    func eachScopeGetsItsOwnViewModel() {
        let root = makeRoot()
        let scope = root.makeChild()

        #expect(scope.resolve(EpisodesViewModel.self) === scope.resolve(EpisodesViewModel.self))
        #expect(root.makeChild().resolve(EpisodesViewModel.self) !== root.makeChild().resolve(EpisodesViewModel.self))
    }

    private func makeRoot(navigator: EpisodesNavigator = EpisodesNavigator()) -> DependencyContainer {
        let root = DependencyContainer()
        EpisodesAssembly.register(in: root,
                                  dependencies: StubEpisodesDependencies(),
                                  navigator: navigator)
        return root
    }
}

/// Stands in for the app container; nothing here reaches the network.
struct StubEpisodesDependencies: EpisodesDependencies {
    let graphQLClient = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!)
    let justWatchClient = GraphQLClient(endpoint: URL(string: "https://example.com/justwatch")!)
    let cacheStore: any CacheStoreContract = CodableCacheStore(
        diskStore: FileDiskStore(
            root: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
    )
}
