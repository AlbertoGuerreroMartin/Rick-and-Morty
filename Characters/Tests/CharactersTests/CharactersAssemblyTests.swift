//
//  CharactersAssemblyTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Core
import Foundation
import Networking
import Storage
import Testing
@testable import Characters

@Suite("CharactersAssembly")
@MainActor
struct CharactersAssemblyTests {

    @Test("a screen scope resolves every registration in its initial state")
    func aScopeResolvesEverything() {
        let navigator = CharactersNavigator()
        let root = makeRoot(navigator: navigator)
        let scope = makeDetailScope(root, id: "1")

        // Nothing is built until it is asked for, so every registration is exercised here.
        scope.resolveAll()

        #expect(scope.resolve((any CharactersUseCaseContract).self) is CharactersUseCase)
        #expect(scope.resolve((any CharacterDetailUseCaseContract).self) is CharacterDetailUseCase)
        #expect(scope.resolve((any CharactersRepositoryContract).self) is CharactersRepository)
        // Passed through, not built here: the scope must hand the screen the object a deep link writes to.
        #expect(scope.resolve(CharactersNavigator.self) === navigator)
        #expect(scope.resolve(CharactersNavigator.self).path.isEmpty)

        let viewModel = scope.resolve(CharactersViewModel.self)
        #expect(viewModel.charactersPublished == nil)
        #expect(viewModel.loadingPublished == false)
        #expect(viewModel.filterPublished == .empty)
    }

    @Test("the data layer is shared by every screen scope")
    func theDataLayerIsShared() {
        let root = makeRoot()

        let first = root.makeChild().resolve((any CharactersRepositoryContract).self)
        let second = root.makeChild().resolve((any CharactersRepositoryContract).self)

        #expect(first as AnyObject === second as AnyObject)
    }

    @Test("each screen scope gets its own view model")
    func eachScopeGetsItsOwnViewModel() {
        let root = makeRoot()
        let scope = root.makeChild()

        #expect(scope.resolve(CharactersViewModel.self) === scope.resolve(CharactersViewModel.self))
        #expect(root.makeChild().resolve(CharactersViewModel.self) !== root.makeChild().resolve(CharactersViewModel.self))
    }

    @Test("every characters section reads its scope's view model")
    func charactersSectionsShareTheViewModel() {
        let scope = makeRoot().makeChild()
        let viewModel = scope.resolve(CharactersViewModel.self)

        #expect(scope.resolve((any CharactersListSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve((any CharactersGridSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve((any CharactersFilterBarSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve(CharactersListSectionMapper.self).viewModel as AnyObject === viewModel)
        #expect(scope.resolve(CharactersGridSectionMapper.self).viewModel as AnyObject === viewModel)
        #expect(scope.resolve(CharactersFilterBarSectionMapper.self).viewModel as AnyObject === viewModel)
    }

    /// A scope that dropped the id would fetch whichever character the server answered for an empty query.
    @Test("the detail scope builds its view model for the route's character")
    func theDetailScopeCarriesTheRoutesId() {
        let scope = makeDetailScope(makeRoot(), id: "42")

        let viewModel = scope.resolve(CharacterDetailViewModel.self)
        #expect(viewModel.id == "42")
        #expect(viewModel.detailPublished == nil)
        #expect(viewModel.loadingPublished == false)
        #expect(viewModel.loadFailedPublished == false)
        #expect(scope.resolve((any CharacterDetailHeaderSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve((any CharacterDetailInfoSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve((any CharacterDetailEpisodesSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve(CharacterDetailHeaderSectionMapper.self).viewModel as AnyObject === viewModel)
        #expect(scope.resolve(CharacterDetailInfoSectionMapper.self).viewModel as AnyObject === viewModel)
        #expect(scope.resolve(CharacterDetailEpisodesSectionMapper.self).viewModel as AnyObject === viewModel)
    }

    @Test("two pushed details are two view models")
    func twoDetailsAreTwoViewModels() {
        let root = makeRoot()

        let first = makeDetailScope(root, id: "1").resolve(CharacterDetailViewModel.self)
        let second = makeDetailScope(root, id: "2").resolve(CharacterDetailViewModel.self)

        #expect(first !== second)
        #expect(first.id == "1")
        #expect(second.id == "2")
    }

    private func makeRoot(navigator: CharactersNavigator = CharactersNavigator()) -> DependencyContainer {
        let root = DependencyContainer()
        CharactersAssembly.register(in: root,
                                    dependencies: StubCharactersDependencies(),
                                    navigator: navigator)
        return root
    }

    /// What `CharacterDetailFactory` does per push: a child scope carrying the route's id.
    private func makeDetailScope(_ root: DependencyContainer, id: String) -> DependencyContainer {
        let scope = root.makeChild()
        scope.register(CharacterDetailContext.self) { _ in CharacterDetailContext(id: id) }
        return scope
    }
}

/// Stands in for the app container; nothing here reaches the network.
struct StubCharactersDependencies: CharactersDependencies {
    let graphQLClient = GraphQLClient(endpoint: URL(string: "https://example.com/graphql")!)
    let justWatchClient = GraphQLClient(endpoint: URL(string: "https://example.com/justwatch")!)
    let cacheStore: any CacheStoreContract = CodableCacheStore(
        diskStore: FileDiskStore(
            root: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
    )
}
