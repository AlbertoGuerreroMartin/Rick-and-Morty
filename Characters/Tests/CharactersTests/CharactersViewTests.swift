//
//  CharactersViewTests.swift
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

@Suite("Characters views")
@MainActor
struct CharactersViewTests {

    // MARK: - The screen

    @Test("the screen draws through its factory")
    func screenDrawsThroughTheFactory() async {
        await render(CharactersFactory.build(root: makeRoot()))
    }

    @Test("the detail draws as a view pushed by someone else's stack")
    func detailDrawsInAForeignStack() async {
        await render(NavigationStack {
            CharactersFactory.buildCharacterDetail(root: makeRoot(), id: "1")
        })
    }

    @Test("showing a character puts its route on the screen's path")
    func showingACharacterPushesIt() async {
        let navigator = CharactersNavigator()
        let root = makeRoot(navigator: navigator)

        await render(CharactersFactory.build(root: root))

        navigator.showCharacter(id: "42")
        #expect(navigator.path == [.detail(id: "42")])

        // Re-render to confirm the pushed route resolves to an actual destination.
        await render(CharactersFactory.build(root: root))
    }

    @Test("the screen's scope starts empty and unfiltered")
    func scopeStartsEmpty() async {
        let scope = makeRoot().makeChild()

        #expect(scope.resolve(CharactersNavigator.self).path.isEmpty)

        let viewModel = scope.resolve(CharactersViewModel.self)
        #expect(viewModel.charactersPublished == nil)
        #expect(viewModel.paginationPublished == .end)
        #expect(viewModel.filterPublished == .empty)
    }

    // MARK: - The chip bar and the filter sheet

    @Test("the chip bar draws with no filters at all")
    func chipBarDrawsEmpty() async {
        await renderFilterBar(StubCharactersFilterBarViewsViewModel())
    }

    @Test("the chip bar draws a chip per active field")
    func chipBarDrawsItsChips() async {
        let viewModel = StubCharactersFilterBarViewsViewModel()
        viewModel.filter = CharactersFilter(name: "rick",
                                            status: .alive,
                                            species: "Human",
                                            type: "Parasite",
                                            gender: .male)

        await renderFilterBar(viewModel)
    }

    @Test("the filter sheet draws, empty and populated")
    func filterSheetDraws() async {
        await render(CharactersFilterSheet(initial: .empty, onApply: { _ in }))
        await render(CharactersFilterSheet(initial: CharactersFilter(name: "rick",
                                                                     status: .dead,
                                                                     species: "Human",
                                                                     type: "Parasite",
                                                                     gender: .female),
                                           onApply: { _ in }))
    }

    // MARK: - The shared leaves

    /// Both shapes of the no-matches state: with and without a Clear filters button.
    @Test("every empty state draws")
    func emptyStatesDraw() async {
        await render(CharactersEmptyStateView(reason: .noMatches(summary: "“rick” with Alive · Human",
                                                                 canClearFilters: true),
                                              onClearFilters: {}, onRetry: {}))
        await render(CharactersEmptyStateView(reason: .noMatches(summary: nil, canClearFilters: false),
                                              onClearFilters: {}, onRetry: {}))
        await render(CharactersEmptyStateView(reason: .failed, onClearFilters: {}, onRetry: {}))
    }

    /// `.loadMore` and `.loading` draw the same spinner on purpose: two identities would
    /// cancel the very task that moves one state to the other.
    @Test("every pagination footer draws", arguments: [
        CharactersSectionFooter.loadMore,
        .loading,
        .retry,
        .none
    ])
    func paginationFootersDraw(footer: CharactersSectionFooter) async {
        await render(List {
            CharactersPaginationFooterView(footer: footer, loadedCount: 20, loadNextPage: {})
        })
    }

    // MARK: - The results sections

    @Test("the list section draws the spinner while loading")
    func listDrawsWhileLoading() async {
        let viewModel = StubCharactersSectionViewModel()
        viewModel.isLoading = true

        await renderList(viewModel)
    }

    @Test("the list section draws a search that matched nothing")
    func listDrawsNoMatches() async {
        let viewModel = StubCharactersSectionViewModel()
        viewModel.characters = []
        viewModel.filter = CharactersFilter(name: "squanch", status: .alive)

        await renderList(viewModel)
    }

    @Test("the list section draws a failed load")
    func listDrawsAFailure() async {
        let viewModel = StubCharactersSectionViewModel()
        viewModel.characters = []
        viewModel.loadFailed = true

        await renderList(viewModel)
    }

    @Test("the list section draws rows with a highlight and a footer")
    func listDrawsRows() async {
        let viewModel = StubCharactersSectionViewModel()
        viewModel.characters = [.rick, .morty]
        viewModel.filter = CharactersFilter(name: "rick")
        viewModel.pagination = .idle(nextPage: 2)

        await renderList(viewModel)
    }

    @Test("the grid section draws the spinner while loading")
    func gridDrawsWhileLoading() async {
        let viewModel = StubCharactersSectionViewModel()
        viewModel.isLoading = true

        await renderGrid(viewModel)
    }

    @Test("the grid section draws a failed load")
    func gridDrawsAFailure() async {
        let viewModel = StubCharactersSectionViewModel()
        viewModel.characters = []
        viewModel.loadFailed = true

        await renderGrid(viewModel)
    }

    @Test("the grid section draws cells with a highlight and a footer")
    func gridDrawsCells() async {
        let viewModel = StubCharactersSectionViewModel()
        viewModel.characters = [.rick, .morty]
        viewModel.filter = CharactersFilter(name: "morty")
        viewModel.pagination = .failed(nextPage: 2)

        await renderGrid(viewModel)
    }

    // MARK: - Hosting

    /// The real wiring, so a rendered screen resolves the same graph the app does.
    private func makeRoot(navigator: CharactersNavigator = CharactersNavigator()) -> DependencyContainer {
        let root = DependencyContainer()
        CharactersAssembly.register(in: root,
                                    dependencies: StubCharactersDependencies(),
                                    navigator: navigator)
        return root
    }

    /// Hosted inside a `NavigationStack`: their rows are `NavigationLink`s now, and a
    /// link outside a stack is a row that does nothing.
    private func renderList(_ viewModel: StubCharactersSectionViewModel) async {
        await render(NavigationStack {
            CharactersListSectionView(
                viewModel: viewModel,
                renderModelPublisher: CharactersListSectionMapper(viewModel: viewModel).renderModelPublisher()
            )
        })
    }

    private func renderGrid(_ viewModel: StubCharactersSectionViewModel) async {
        await render(NavigationStack {
            CharactersGridSectionView(
                viewModel: viewModel,
                renderModelPublisher: CharactersGridSectionMapper(viewModel: viewModel).renderModelPublisher()
            )
        })
    }

    private func renderFilterBar(_ viewModel: StubCharactersFilterBarViewsViewModel) async {
        await render(CharactersFilterBarSectionView(
            viewModel: viewModel,
            renderModelPublisher: CharactersFilterBarSectionMapper(viewModel: viewModel).renderModelPublisher()
        ))
    }

    /// Hosts `view` on a sized window and forces layout twice: once for the initial
    /// state, once after the mapper's `.receive(on: .main)` delivers.
    private func render(_ view: some View) async {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()

        for _ in 0..<10 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(20))

        window.layoutIfNeeded()
        window.isHidden = true
    }
}

// MARK: - Test doubles

/// internal, not private: also used by `CharactersFilterBarSectionMapperTests`.
@MainActor
final class StubCharactersFilterBarViewsViewModel: CharactersFilterBarSectionViewModelContract {
    @Published var filter: CharactersFilter = .empty

    private(set) var appliedFilters: [CharactersFilter] = []
    private(set) var clearedFields: [CharactersFilter.Field] = []
    private(set) var clearAllCallCount = 0

    var filterPublisher: AnyPublisher<CharactersFilter, Never> { $filter.eraseToAnyPublisher() }

    func apply(_ filter: CharactersFilter) {
        appliedFilters.append(filter)
    }

    func clear(_ field: CharactersFilter.Field) {
        clearedFields.append(field)
    }

    func clearAllFilters() {
        clearAllCallCount += 1
    }
}
