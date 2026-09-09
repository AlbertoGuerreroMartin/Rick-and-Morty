//
//  CharactersAssemblyTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Core
import Foundation
import Testing
@testable import Characters

@Suite("CharactersAssembly")
@MainActor
struct CharactersAssemblyTests {

    @Test("a screen scope resolves every registration in its initial state")
    func aScopeResolvesEverything() throws {
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
        // The screen resolves the contract; it must land on the concrete view model.
        #expect(scope.resolve((any CharactersViewModelContract).self) is CharactersViewModel)
        #expect(scope.resolve((any CharacterDetailViewModelContract).self) is CharacterDetailViewModel)

        let viewModel = try #require(scope.resolve((any CharactersViewModelContract).self) as? CharactersViewModel)
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

        #expect(scope.resolve((any CharactersViewModelContract).self) as AnyObject
            === scope.resolve((any CharactersViewModelContract).self) as AnyObject)
        #expect(root.makeChild().resolve((any CharactersViewModelContract).self) as AnyObject
            !== root.makeChild().resolve((any CharactersViewModelContract).self) as AnyObject)
    }

    @Test("every characters section reads its scope's view model")
    func charactersSectionsShareTheViewModel() {
        let scope = makeRoot().makeChild()
        let viewModel = scope.resolve((any CharactersViewModelContract).self) as AnyObject

        #expect(scope.resolve((any CharactersListSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve((any CharactersGridSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve((any CharactersFilterBarSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve((any CharactersListSectionMapperContract).self).viewModel as AnyObject === viewModel)
        #expect(scope.resolve((any CharactersGridSectionMapperContract).self).viewModel as AnyObject === viewModel)
        #expect(scope.resolve((any CharactersFilterBarSectionMapperContract).self).viewModel as AnyObject === viewModel)
    }

    /// A scope that dropped the id would fetch whichever character the server answered for an empty query.
    @Test("the detail scope builds its view model for the route's character")
    func theDetailScopeCarriesTheRoutesId() throws {
        let scope = makeDetailScope(makeRoot(), id: "42")

        let viewModel = try #require(scope.resolve((any CharacterDetailViewModelContract).self) as? CharacterDetailViewModel)
        #expect(viewModel.id == "42")
        #expect(viewModel.detailPublished == nil)
        #expect(viewModel.loadingPublished == false)
        #expect(viewModel.loadFailedPublished == false)
        #expect(scope.resolve((any CharacterDetailHeaderSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve((any CharacterDetailInfoSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve((any CharacterDetailEpisodesSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve((any CharacterDetailHeaderSectionMapperContract).self).viewModel as AnyObject === viewModel)
        #expect(scope.resolve((any CharacterDetailInfoSectionMapperContract).self).viewModel as AnyObject === viewModel)
        #expect(scope.resolve((any CharacterDetailEpisodesSectionMapperContract).self).viewModel as AnyObject === viewModel)
    }

    @Test("two pushed details are two view models")
    func twoDetailsAreTwoViewModels() throws {
        let root = makeRoot()

        let first = try #require(makeDetailScope(root, id: "1")
            .resolve((any CharacterDetailViewModelContract).self) as? CharacterDetailViewModel)
        let second = try #require(makeDetailScope(root, id: "2")
            .resolve((any CharacterDetailViewModelContract).self) as? CharacterDetailViewModel)

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
