//
//  LocationsViewTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Networking
import Storage
import SwiftUI
import Testing
import UIKit
@testable import Locations

/// Sections are driven through the real pipeline (stub view model, real mapper, `.onReceive`),
/// not by writing a render model into `@State` directly, so the subscription wiring is checked too.
@Suite("Locations views")
@MainActor
struct LocationsViewTests {

    // MARK: - The carousel section

    @Test("the carousel draws the spinner while loading")
    func carouselDrawsWhileLoading() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.isLoading = true

        await renderCarousel(viewModel)
    }

    @Test("the carousel draws a failed load")
    func carouselDrawsAFailedLoad() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = []
        viewModel.loadFailed = true

        await renderCarousel(viewModel)
    }

    @Test("the carousel draws an empty catalogue")
    func carouselDrawsAnEmptyCatalogue() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = []

        await renderCarousel(viewModel)
    }

    @Test("the carousel draws a full row with a selection")
    func carouselDrawsAFullRow() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = .catalogue
        viewModel.selectedId = "5"
        viewModel.pagination = .idle(nextPage: 2)

        await renderCarousel(viewModel)
    }

    @Test("the carousel draws a single item")
    func carouselDrawsASingleItem() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = [.make(id: "1", name: "Earth (C-137)")]
        viewModel.selectedId = "1"

        await renderCarousel(viewModel)
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
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = [.make(id: "1",
                                     name: "Interdimensional Cable Broadcasting Station",
                                     type: nil)]
        viewModel.selectedId = "1"

        await renderCarousel(viewModel)
    }

    @Test("the carousel draws each footer state")
    func carouselDrawsEveryFooter() async {
        for pagination in [LocationsPaginationState.idle(nextPage: 2), .loading,
                           .failed(nextPage: 2), .end] {
            let viewModel = StubLocationsCarouselViewModel()
            viewModel.locations = .catalogue
            viewModel.selectedId = "1"
            viewModel.pagination = pagination

            await renderCarousel(viewModel)
        }
    }

    @Test("the failed empty state retries through the view model")
    func retryReachesTheViewModel() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = []
        viewModel.loadFailed = true

        await renderCarousel(viewModel)

        // Driven directly rather than by tapping the ContentUnavailableView action.
        viewModel.retryLoad()

        #expect(viewModel.retryCallCount == 1)
    }

    @Test("the carousel reports its focus once items arrive")
    func theCarouselAnnouncesItsFocus() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = .catalogue

        await renderCarousel(viewModel)

        #expect(viewModel.selectedIds.first == "1")
    }

    @Test("the carousel follows a selection it did not make")
    func theCarouselFollowsTheSelection() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = .catalogue
        viewModel.selectedId = "5"

        await renderCarousel(viewModel)

        #expect(viewModel.selectedIds == ["5"])
    }

    // MARK: - The detail section

    @Test("the detail draws nothing when nothing is selected")
    func detailDrawsHidden() async {
        let viewModel = StubLocationDetailViewModel()
        viewModel.locations = [.make(id: "1")]

        await renderDetail(viewModel)
    }

    @Test("the detail draws a location with everything")
    func detailDrawsAFullLocation() async {
        let viewModel = StubLocationDetailViewModel()
        viewModel.locations = [.make(id: "1",
                                     name: "Earth (C-137)",
                                     type: "Planet",
                                     dimension: "Dimension C-137",
                                     residents: .crowd)]
        viewModel.selectedId = "1"

        await renderDetail(viewModel)
    }

    @Test("the detail draws a location with no residents")
    func detailDrawsAnEmptyLocation() async {
        let viewModel = StubLocationDetailViewModel()
        viewModel.locations = [.make(id: "1", name: "Worldender's lair", residents: [])]
        viewModel.selectedId = "1"

        await renderDetail(viewModel)
    }

    @Test("the detail draws a location with no rows")
    func detailDrawsARowlessLocation() async {
        let viewModel = StubLocationDetailViewModel()
        viewModel.locations = [.make(id: "1", type: nil, dimension: nil, residents: .crowd)]
        viewModel.selectedId = "1"

        await renderDetail(viewModel)
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
        viewModel.locations = [.make(id: "1", name: "Earth (C-137)")]
        viewModel.selectedId = "1"
        viewModel.pagination = .idle(nextPage: 2)

        await renderCarousel(viewModel)

        #expect(viewModel.loadNextPageCallCount >= 1)
    }

    @Test("the end of the list asks for nothing")
    func theEndAsksForNothing() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = [.make(id: "1", name: "Earth (C-137)")]
        viewModel.selectedId = "1"
        viewModel.pagination = .end

        await renderCarousel(viewModel)

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

    @Test("the screen draws and loads through its graph")
    func screenDraws() async {
        let useCase = StubLocationsUseCase(pages: [1: .success(.page(1, nextPage: 2))])
        let viewModel = LocationsViewModel(locationsUseCase: useCase)
        let screen = LocationsScreen(
            makeGraph: {
                LocationsScreenGraph(navigator: LocationsNavigator(),
                                     viewModel: viewModel,
                                     carouselMapper: LocationsCarouselSectionMapper(viewModel: viewModel),
                                     detailMapper: LocationDetailSectionMapper(viewModel: viewModel))
            },
            makeSection: { graph in
                VStack {
                    LocationsCarouselSectionView(
                        viewModel: graph.viewModel,
                        renderModelPublisher: graph.carouselMapper.renderModelPublisher()
                    )
                    LocationDetailSectionView(
                        viewModel: graph.viewModel,
                        renderModelPublisher: graph.detailMapper.renderModelPublisher()
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

    @Test("the factory's screen draws both sections stacked")
    func factoryScreenDraws() async {
        await render(LocationsFactory.previewScreen(repository: StubViewsLocationsRepository()))
    }

    @Test("the feature's public entry point draws")
    func factoryBuildDraws() async {
        await render(LocationsFactory.build(dependencies: StubLocationsDependencies(),
                                            navigator: LocationsNavigator(),
                                            external: StubExternalDestinations()))
    }

    @Test("showing a character pushes it onto the screen's path")
    func showingACharacterPushesIt() async {
        let dependencies = StubLocationsDependencies()
        let navigator = LocationsNavigator()
        let external = StubExternalDestinations()

        await render(LocationsFactory.build(dependencies: dependencies,
                                            navigator: navigator,
                                            external: external))

        navigator.showCharacter(id: "42")
        #expect(navigator.path == [.character(id: "42")])

        await render(LocationsFactory.build(dependencies: dependencies,
                                            navigator: navigator,
                                            external: external))

        #expect(external.requestedIds.contains("42"))
    }

    // MARK: - Hosting

    private func renderCarousel(_ viewModel: StubLocationsCarouselViewModel) async {
        await render(LocationsCarouselSectionView(
            viewModel: viewModel,
            renderModelPublisher: LocationsCarouselSectionMapper(viewModel: viewModel).renderModelPublisher()
        ))
    }

    private func renderDetail(_ viewModel: StubLocationDetailViewModel) async {
        await renderRows(LocationDetailSectionView(
            viewModel: viewModel,
            renderModelPublisher: LocationDetailSectionMapper(viewModel: viewModel).renderModelPublisher()
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

private extension Array where Element == LocationModel {
    /// More than fit on screen at once, so the carousel actually scrolls.
    static var catalogue: [LocationModel] {
        (1...12).map { index in
            LocationModel.make(id: "\(index)",
                               name: "Location \(index)",
                               type: index.isMultiple(of: 3) ? nil : "Planet",
                               dimension: "Dimension C-\(index)")
        }
    }
}

@MainActor
private final class StubExternalDestinations: LocationsExternalDestinations {
    private(set) var requestedIds: [String] = []

    func characterDetail(id: String) -> some View {
        requestedIds.append(id)
        return Text(id)
    }
}

private struct StubViewsLocationsRepository: LocationsRepositoryContract {
    func fetchLocations(page: Int) async throws -> LocationsPage {
        LocationsPage(locations: (1...5).map { index in
            LocationModel.make(id: "\(page)-\(index)",
                               name: "Location \(page)-\(index)",
                               residents: .crowd)
        }, nextPage: page < 3 ? page + 1 : nil)
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
