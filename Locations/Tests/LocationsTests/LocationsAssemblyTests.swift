//
//  LocationsAssemblyTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Core
import Foundation
import Testing
@testable import Locations

@Suite("LocationsAssembly")
@MainActor
struct LocationsAssemblyTests {

    @Test("a screen scope resolves every registration in its initial state")
    func aScopeResolvesEverything() throws {
        let scope = makeRoot().makeChild()

        // Nothing is built until it is asked for, so every registration is exercised here.
        scope.resolveAll()

        #expect(scope.resolve((any LocationsUseCaseContract).self) is LocationsUseCase)
        #expect(scope.resolve((any LocationsRepositoryContract).self) is LocationsRepository)

        // The screen resolves the contract; it must land on the concrete view model.
        #expect(scope.resolve((any LocationsViewModelContract).self) is LocationsViewModel)

        let viewModel = try #require(scope.resolve((any LocationsViewModelContract).self) as? LocationsViewModel)
        #expect(viewModel.locationsPublished == nil)
        #expect(viewModel.loadingPublished == false)
        #expect(viewModel.loadFailedPublished == false)
        #expect(viewModel.selectedLocationIdPublished == nil)
        #expect(viewModel.paginationPublished == .end)
    }

    @Test("the data layer is shared by every screen scope")
    func theDataLayerIsShared() {
        let root = makeRoot()

        let first = root.makeChild().resolve((any LocationsRepositoryContract).self)
        let second = root.makeChild().resolve((any LocationsRepositoryContract).self)

        #expect(first as AnyObject === second as AnyObject)
    }

    @Test("each screen scope gets its own view model")
    func eachScopeGetsItsOwnViewModel() {
        let root = makeRoot()
        let scope = root.makeChild()

        #expect(scope.resolve((any LocationsViewModelContract).self) as AnyObject
            === scope.resolve((any LocationsViewModelContract).self) as AnyObject)
        #expect(root.makeChild().resolve((any LocationsViewModelContract).self) as AnyObject
            !== root.makeChild().resolve((any LocationsViewModelContract).self) as AnyObject)
    }

    @Test("both sections resolve their scope's view model")
    func bothSectionsShareTheViewModel() {
        let scope = makeRoot().makeChild()
        let viewModel = scope.resolve((any LocationsViewModelContract).self) as AnyObject

        #expect(scope.resolve((any LocationsCarouselSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve((any LocationDetailSectionViewModelContract).self) as AnyObject === viewModel)
        #expect(scope.resolve((any LocationsCarouselSectionMapperContract).self).viewModel as AnyObject === viewModel)
        #expect(scope.resolve((any LocationDetailSectionMapperContract).self).viewModel as AnyObject === viewModel)
    }

    @Test("the scope carries the navigator the assembly was handed")
    func theScopeCarriesTheNavigator() {
        let navigator = LocationsNavigator()
        let scope = makeRoot(navigator: navigator).makeChild()

        // Passed through, not rebuilt: the scope must hand the screen this exact instance.
        #expect(scope.resolve(LocationsNavigator.self) === navigator)
        #expect(scope.resolve(LocationsNavigator.self).path.isEmpty)
    }

    /// A registered repository replaces the one the assembly would build: last registration wins.
    @Test("a later registration overrides the wiring")
    func aLaterRegistrationOverridesTheWiring() {
        let root = makeRoot()
        root.register((any LocationsRepositoryContract).self) { _ in StubLocationsRepository() }

        #expect(root.makeChild().resolve((any LocationsRepositoryContract).self) is StubLocationsRepository)
    }

    private func makeRoot(navigator: LocationsNavigator = LocationsNavigator()) -> DependencyContainer {
        let root = DependencyContainer()
        LocationsAssembly.register(in: root,
                                   dependencies: StubLocationsDependencies(),
                                   navigator: navigator)
        return root
    }
}
