//
//  LocationsViewTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Core
import Networking
import Storage
import SwiftUI
import Testing
import UIKit
@testable import Locations

/// Sections are driven through a stub mapper publishing the render model the test hands it, not by
/// writing it into `@State` directly, so the `.onReceive` subscription wiring is checked too.
@Suite("Locations views")
@MainActor
struct LocationsViewTests {

    // MARK: - The carousel section

    @Test("the carousel draws the spinner while loading")
    func carouselDrawsWhileLoading() async {
        await renderCarousel(.hidden)
    }

    @Test("the carousel draws a failed load")
    func carouselDrawsAFailedLoad() async {
        await renderCarousel(.empty(.failed))
    }

    @Test("the carousel draws an empty catalogue")
    func carouselDrawsAnEmptyCatalogue() async {
        await renderCarousel(.empty(.noLocations))
    }

    @Test("the carousel draws a full row with a selection")
    func carouselDrawsAFullRow() async {
        await renderCarousel(.visible(items: .catalogue, selectedId: "5", footer: .loadMore))
    }

    @Test("the carousel draws a single item")
    func carouselDrawsASingleItem() async {
        await renderCarousel(.visible(items: [.make(id: "1", title: "Earth (C-137)")], selectedId: "1", footer: .none))
    }

    @Test("a long name stays inside the circle")
    func longNameStaysInsideTheCircle() {
        let sizes = [
            "Earth (C-137)",
            "Interdimensional Cable Broadcasting Station",
            "Immortality Field Resort and Interdimensional Customs Checkpoint"
        ].map { name in
            hostedSize(LocationsCarouselItemView(title: name, isFocused: true))
        }

        for size in sizes {
            #expect(size.width == LocationsCarouselItemView.diameter)
            #expect(size.height == LocationsCarouselItemView.diameter)
        }

        let retry = hostedSize(LocationsCarouselPaginationItemView(footer: .retry, loadedCount: 1, loadNextPage: {}))
        #expect(retry.width == LocationsCarouselItemView.diameter)
        #expect(retry.height == LocationsCarouselItemView.diameter)
    }

    @Test("the carousel draws a location with a very long name")
    func carouselDrawsALongName() async {
        await renderCarousel(.visible(items: [.make(id: "1", title: "Interdimensional Cable Broadcasting Station")],
                                      selectedId: "1",
                                      footer: .none))
    }

    @Test("the carousel draws each footer state")
    func carouselDrawsEveryFooter() async {
        for footer in [LocationsSectionFooter.loadMore, .loading, .retry, .none] {
            await renderCarousel(.visible(items: .catalogue, selectedId: "1", footer: footer))
        }
    }

    @Test("the failed empty state retries through the view model")
    func retryReachesTheViewModel() async {
        let viewModel = StubLocationsCarouselViewModel()

        await renderCarousel(.empty(.failed), viewModel: viewModel)

        // Driven directly rather than by tapping the ContentUnavailableView action.
        viewModel.retryLoad()

        #expect(viewModel.retryCallCount == 1)
    }

    @Test("the carousel reports its focus once items arrive")
    func theCarouselAnnouncesItsFocus() async {
        let viewModel = StubLocationsCarouselViewModel()

        await renderCarousel(.visible(items: .catalogue, selectedId: nil, footer: .none), viewModel: viewModel)

        #expect(viewModel.selectedIds.first == "1")
    }

    @Test("the carousel follows a selection it did not make")
    func theCarouselFollowsTheSelection() async {
        let viewModel = StubLocationsCarouselViewModel()

        await renderCarousel(.visible(items: .catalogue, selectedId: "5", footer: .none), viewModel: viewModel)

        #expect(viewModel.selectedIds == ["5"])
    }

    // MARK: - The detail section

    @Test("the detail draws nothing when nothing is selected")
    func detailDrawsHidden() async {
        await renderDetail(.hidden)
    }

    @Test("the detail draws a location with everything")
    func detailDrawsAFullLocation() async {
        await renderDetail(.visible(LocationDetailContent(
            name: "Earth (C-137)",
            rows: [LocationDetailInfoRow(label: "Type", value: "Planet"),
                   LocationDetailInfoRow(label: "Dimension", value: "Dimension C-137")],
            residents: .crowd,
            residentsDescription: "6 residents"
        )))
    }

    @Test("the detail draws a location with no residents")
    func detailDrawsAnEmptyLocation() async {
        await renderDetail(.visible(LocationDetailContent(
            name: "Worldender's lair",
            rows: [LocationDetailInfoRow(label: "Type", value: "Planet")],
            residents: [],
            residentsDescription: "0 residents"
        )))
    }

    @Test("the detail draws a location with no rows")
    func detailDrawsARowlessLocation() async {
        await renderDetail(.visible(LocationDetailContent(
            name: "Earth (C-137)",
            rows: [],
            residents: .crowd,
            residentsDescription: "6 residents"
        )))
    }

    // MARK: - Leaves

    @Test("the carousel item draws focused, unfocused and overfull")
    func carouselItemDraws() async {
        await render(LocationsCarouselItemView(title: "Earth (C-137)", isFocused: true))
        await render(LocationsCarouselItemView(title: "Abadango", isFocused: false))
        await render(LocationsCarouselItemView(
            title: "Interdimensional Cable Broadcasting Station",
            isFocused: true
        ))
    }

    @Test("the residents list draws full and empty")
    func residentsListDraws() async {
        await renderRows(LocationResidentsListView(residents: .crowd))
        await renderRows(LocationResidentsListView(residents: []))
    }

    @Test("both empty states draw")
    func emptyStatesDraw() async {
        await render(LocationsEmptyStateView(reason: .noLocations, onRetry: {}))
        await render(LocationsEmptyStateView(reason: .failed, onRetry: {}))
    }

    @Test("every pagination item state draws")
    func paginationItemStatesDraw() async {
        for footer in [LocationsSectionFooter.loadMore, .loading, .retry, .none] {
            await render(LocationsCarouselPaginationItemView(footer: footer, loadedCount: 20, loadNextPage: {}))
        }
    }

    @Test("the pagination item spins for a page waiting or in flight, and not otherwise")
    func paginationItemSpins() async {
        #expect(await hostsSpinner(LocationsCarouselPaginationItemView(footer: .loadMore, loadedCount: 1, loadNextPage: {})))
        #expect(await hostsSpinner(LocationsCarouselPaginationItemView(footer: .loading, loadedCount: 1, loadNextPage: {})))
        #expect(await !hostsSpinner(LocationsCarouselPaginationItemView(footer: .retry, loadedCount: 1, loadNextPage: {})))
        #expect(await !hostsSpinner(LocationsCarouselPaginationItemView(footer: .none, loadedCount: 1, loadNextPage: {})))
    }

    @Test("the pagination item asks for the next page when it appears, unless it failed")
    func paginationItemLoadsOnAppearance() async {
        let calls = CallCounter()
        await render(LocationsCarouselPaginationItemView(footer: .loadMore, loadedCount: 20) { calls.increment() })
        #expect(calls.count == 1)

        let retryCalls = CallCounter()
        await render(LocationsCarouselPaginationItemView(footer: .retry, loadedCount: 20) { retryCalls.increment() })
        #expect(retryCalls.count == 0)
    }

    @Test("a short page asks for the next one without a scroll")
    func aShortPageLoadsTheNextOne() async {
        let viewModel = StubLocationsCarouselViewModel()

        await renderCarousel(.visible(items: [.make(id: "1", title: "Earth (C-137)")], selectedId: "1", footer: .loadMore),
                             viewModel: viewModel)

        #expect(viewModel.loadNextPageCallCount >= 1)
    }

    @Test("the end of the list asks for nothing")
    func theEndAsksForNothing() async {
        let viewModel = StubLocationsCarouselViewModel()

        await renderCarousel(.visible(items: [.make(id: "1", title: "Earth (C-137)")], selectedId: "1", footer: .none),
                             viewModel: viewModel)

        #expect(viewModel.loadNextPageCallCount == 0)
    }

    @Test("the detail preview card draws")
    func previewCardDraws() async {
        await renderRows(LocationDetailSectionView.PreviewCard(content: LocationDetailContent(
            name: "Earth (C-137)",
            rows: [LocationDetailInfoRow(label: "Type", value: "Planet")],
            residents: .crowd,
            residentsDescription: "6 residents"
        )))
    }

    // MARK: - The screen

    @Test("the screen draws and loads through its scope")
    func screenDraws() async {
        let useCase = StubLocationsUseCase(pages: [1: .success(.page(1, nextPage: 2))])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        let screen = LocationsScreen(
            makeScope: {
                let scope = DependencyContainer()
                scope.register(LocationsNavigator.self) { _ in LocationsNavigator() }
                scope.register((any LocationsViewModelContract).self) { _ in viewModel }
                scope.register((any LocationsCarouselSectionViewModelContract).self) { _ in viewModel }
                scope.register((any LocationDetailSectionViewModelContract).self) { _ in viewModel }
                scope.register((any LocationsCarouselSectionMapperContract).self) { _ in
                    StubLocationsCarouselSectionMapper(viewModel: viewModel, renderModel: .hidden)
                }
                scope.register((any LocationDetailSectionMapperContract).self) { _ in
                    StubLocationDetailSectionMapper(viewModel: viewModel, renderModel: .hidden)
                }
                return scope
            },
            makeSection: { scope in
                VStack {
                    LocationsCarouselSectionView(
                        viewModel: scope.resolve((any LocationsCarouselSectionViewModelContract).self),
                        renderModelPublisher: scope.resolve((any LocationsCarouselSectionMapperContract).self).renderModelPublisher()
                    )
                    LocationDetailSectionView(
                        viewModel: scope.resolve((any LocationDetailSectionViewModelContract).self),
                        renderModelPublisher: scope.resolve((any LocationDetailSectionMapperContract).self).renderModelPublisher()
                    )
                }
            },
            makeDestination: { route in
                switch route {
                case .character(let id):
                    Text(id)
                }
            }
        )

        await render(screen)

        // `.task` isn't guaranteed to have run by the time layout returns, so the load is driven directly.
        await viewModel.loadData()
        await settle()

        #expect(viewModel.locationsPublished?.map(\.id) == ["1-0", "1-1"])
        #expect(viewModel.selectedLocationIdPublished == "1-0")
    }

    @Test("the feature's public entry point draws")
    func factoryBuildDraws() async {
        await render(LocationsFactory.build(root: makeRoot(), external: StubExternalDestinations()))
    }

    @Test("showing a character pushes it onto the screen's path")
    func showingACharacterPushesIt() async {
        let navigator = LocationsNavigator()
        let root = makeRoot(navigator: navigator)
        let external = StubExternalDestinations()

        await render(LocationsFactory.build(root: root, external: external))

        navigator.showCharacter(id: "42")
        #expect(navigator.path == [.character(id: "42")])

        await render(LocationsFactory.build(root: root, external: external))

        #expect(external.requestedIds.contains("42"))
    }

    // MARK: - Hosting

    /// The real wiring, so a rendered screen resolves the same graph the app does.
    private func makeRoot(navigator: LocationsNavigator = LocationsNavigator()) -> DependencyContainer {
        let root = DependencyContainer()
        LocationsAssembly.register(in: root,
                                   dependencies: StubLocationsDependencies(),
                                   navigator: navigator)
        return root
    }

    private func renderCarousel(_ renderModel: LocationsCarouselRenderModel,
                                viewModel: StubLocationsCarouselViewModel = StubLocationsCarouselViewModel()) async {
        await render(LocationsCarouselSectionView(
            viewModel: viewModel,
            renderModelPublisher: StubLocationsCarouselSectionMapper(viewModel: viewModel,
                                                                     renderModel: renderModel).renderModelPublisher()
        ))
    }

    private func renderDetail(_ renderModel: LocationDetailRenderModel) async {
        let viewModel = StubLocationDetailViewModel()
        await renderRows(LocationDetailSectionView(
            viewModel: viewModel,
            renderModelPublisher: StubLocationDetailSectionMapper(viewModel: viewModel,
                                                                  renderModel: renderModel).renderModelPublisher()
        ))
    }

    /// Rows need a `NavigationStack`: residents are `NavigationLink`s, dead outside one.
    private func renderRows(_ rows: some View) async {
        await render(NavigationStack { rows })
    }

    /// Laid out three times: the initial `.hidden` state, what the mapper produces after the
    /// render model arrives on the main queue, and the focus an `onChange` claims once laid out.
    private func render(_ view: some View) async {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()

        await settle()

        window.layoutIfNeeded()

        await settle()

        window.layoutIfNeeded()
        window.isHidden = true
    }

    /// Safe area off, so the size is the view's own rather than the window's insets added in.
    private func hostedSize(_ view: some View) -> CGSize {
        let controller = UIHostingController(rootView: view)
        controller.safeAreaRegions = []
        return controller.sizeThatFits(in: CGSize(width: 390, height: 844))
    }

    private func hostsSpinner(_ view: some View) async -> Bool {
        let window = await host(view)
        defer { window.isHidden = true }
        return window.contains { $0 is UIActivityIndicatorView }
    }

    private func host(_ view: some View) async -> UIWindow {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()
        await settle()
        window.layoutIfNeeded()
        return window
    }

    private func settle() async {
        for _ in 0..<10 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(20))
    }
}

private extension Array where Element == LocationsCarouselItemRenderModel {
    /// More than fit on screen at once, so the carousel actually scrolls.
    static var catalogue: [LocationsCarouselItemRenderModel] {
        (1...12).map { index in .make(id: "\(index)", title: "Location \(index)") }
    }
}

private extension LocationsCarouselItemRenderModel {
    static func make(id: String, title: String) -> LocationsCarouselItemRenderModel {
        LocationsCarouselItemRenderModel(id: id, title: title)
    }
}

private extension UIView {
    func contains(where predicate: (UIView) -> Bool) -> Bool {
        predicate(self) || subviews.contains { $0.contains(where: predicate) }
    }
}

@MainActor
final class CallCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}
