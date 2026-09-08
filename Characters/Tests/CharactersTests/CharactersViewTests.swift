//
//  CharactersViewTests.swift
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

/// The list screen's own views, hosted the way `CharacterDetailViewTests` hosts
/// the detail's: a `UIHostingController` on a sized window with a forced layout
/// pass, because a SwiftUI `body` is lazy and a crash in one survives any test
/// that only builds the value.
///
/// They were worth adding now rather than earlier for one reason in particular:
/// both results sections have just grown a `NavigationLink` around every row,
/// and a link is the kind of change that compiles perfectly and then does
/// nothing — or draws every cell tinted blue — until something actually lays it
/// out inside a navigation stack.
@Suite("Characters views")
@MainActor
struct CharactersViewTests {

    // MARK: - The screen

    /// The whole screen through its real factory: the stack, the toolbar, the
    /// search bar, the chip bar and one of the two results sections, with the
    /// `navigationDestination` the rows push into. Everything below the factory
    /// is constructor-injected, so a missing edge is a compile error here rather
    /// than a blank tab at runtime.
    @Test("the screen draws through its factory")
    func screenDrawsThroughTheFactory() async {
        await render(CharactersFactory.build(dependencies: StubCharactersDependencies()))
    }

    /// The graph is what the screen owns for its identity, so its initial state
    /// is what the sections first subscribe to.
    @Test("the screen's graph starts empty and unfiltered")
    func graphStartsEmpty() async {
        let graph = CharactersFactory.makeGraph(dependencies: StubCharactersDependencies())

        #expect(graph.viewModel.charactersPublished == nil)
        #expect(graph.viewModel.paginationPublished == .end)
        #expect(graph.viewModel.filterPublished == .empty)
    }

    // MARK: - The chip bar and the filter sheet

    @Test("the chip bar draws with no filters at all")
    func chipBarDrawsEmpty() async {
        await renderFilterBar(StubCharactersFilterBarViewsViewModel())
    }

    /// The bar with something in it: a chip per active field, a count on the
    /// button and the "Clear all" that only appears when there is something to
    /// clear.
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

    /// The sheet is a `Form` of pickers and text fields over a *draft*, and it
    /// is the one view in this feature that owns editable state of its own —
    /// which is exactly the kind of body that is never evaluated by a test that
    /// only constructs it.
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

    /// Both empty states, and both shapes of the first one: "no results for
    /// <filter>" with a Clear filters button, and the same copy without it when
    /// there is no filter to clear and the button would be a dead end.
    @Test("every empty state draws")
    func emptyStatesDraw() async {
        await render(CharactersEmptyStateView(reason: .noMatches(summary: "“rick” with Alive · Human",
                                                                 canClearFilters: true),
                                              onClearFilters: {}, onRetry: {}))
        await render(CharactersEmptyStateView(reason: .noMatches(summary: nil, canClearFilters: false),
                                              onClearFilters: {}, onRetry: {}))
        await render(CharactersEmptyStateView(reason: .failed, onClearFilters: {}, onRetry: {}))
    }

    /// All four footers. `.loadMore` and `.loading` draw the same spinner on
    /// purpose — two branches would give SwiftUI two identities and cancel the
    /// very task that moved one state to the other — so both are drawn here to
    /// keep that pair honest.
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

    /// Rows with a highlighted match and a footer waiting for the next page —
    /// the shape the screen is in for most of its life.
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

    /// Both results sections are hosted inside a `NavigationStack`: their rows
    /// are `NavigationLink`s now, and a link outside a stack is a row that does
    /// nothing.
    private func renderList(_ viewModel: StubCharactersSectionViewModel) async {
        await render(NavigationStack {
            CharactersListSectionView(viewModel: viewModel,
                                      mapper: CharactersListSectionMapper(viewModel: viewModel))
        })
    }

    private func renderGrid(_ viewModel: StubCharactersSectionViewModel) async {
        await render(NavigationStack {
            CharactersGridSectionView(viewModel: viewModel,
                                      mapper: CharactersGridSectionMapper(viewModel: viewModel))
        })
    }

    private func renderFilterBar(_ viewModel: StubCharactersFilterBarViewsViewModel) async {
        await render(CharactersFilterBarSectionView(
            viewModel: viewModel,
            mapper: CharactersFilterBarSectionMapper(viewModel: viewModel)
        ))
    }

    /// Hosts `view` on a sized window and forces layout, so its `body` actually
    /// runs. A hosting controller with no window lays out nothing.
    ///
    /// Laid out twice around a turn of the main queue: the render model reaches
    /// a section through `.receive(on: DispatchQueue.main)`, so the first pass
    /// draws the initial state and the second draws what the mapper produced.
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

/// Named for this suite: `CharactersFilterBarSectionMapperTests` declares a
/// file-private stub of its own, and this one has to be visible to the hosting
/// helper below.
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
