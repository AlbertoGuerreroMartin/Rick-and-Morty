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

/// SwiftUI bodies are lazy: constructing a view runs no layout, so a crash in a
/// `body` — a force-unwrap, an index past the end of an array, a `ForEach` over
/// duplicate ids — survives every test that only builds the value. These host
/// each view in a real `UIHostingController` on a sized window and force a
/// layout pass, which is what actually evaluates the bodies.
///
/// That matters more here than on a plain list screen. The carousel writes its
/// own `@State` from three `onChange`s while a scroll view is reading the same
/// value back, and the unused `SpiralNavigator` indexes its items array from a
/// continuous offset; both are exactly the kind of code that is correct until an
/// empty list, or a list that got shorter, reaches it.
///
/// The sections are driven through the *real* pipeline — stub view model
/// publishers, real mapper, `.onReceive` — rather than by writing a render model
/// into the view's `@State`. That is the only way to know the subscription is
/// wired at all, and it costs nothing but a turn of the main queue.
///
/// They stay assertion-light on purpose. Snapshotting pixels would test the
/// system's rendering rather than this feature's, and the *contents* of every
/// render model are already pinned by the two mapper suites; what is left to
/// check is that each of them draws at all.
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

    /// The interesting case: enough items that the row scrolls, with a selection
    /// somewhere other than the first one so the external focus move runs too.
    @Test("the carousel draws a full row with a selection")
    func carouselDrawsAFullRow() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = .catalogue
        viewModel.selectedId = "5"
        viewModel.pagination = .idle(nextPage: 2)

        await renderCarousel(viewModel)
    }

    /// One item is where the horizontal insets are larger than the content and
    /// where "the last three items" is also the first one.
    @Test("the carousel draws a single item")
    func carouselDrawsASingleItem() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = [.make(id: "1", name: "Earth (C-137)")]
        viewModel.selectedId = "1"

        await renderCarousel(viewModel)
    }

    /// A name is laid out *inside* the circle, never across it. The stack's
    /// frame is what proposes the circle's width to the text; without it a
    /// long name runs on one line straight past the rim, which is exactly the
    /// bug this pins. Measured through the hosting controller with the safe
    /// area off, so the answer is the item's own size.
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

        // The retry copy has the same constraint.
        let retry = hostedSize(LocationsCarouselPaginationItemView(footer: .retry, loadedCount: 1, loadNextPage: {}))
        #expect(retry.width == LocationsCarouselItemView.diameter)
        #expect(retry.height == LocationsCarouselItemView.diameter)
    }

    /// A name long enough to need all three lines and the scale factor under
    /// them, which is the case the circle's padding has to survive.
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

    /// The Retry button is the only escape from a failed load, so it has to
    /// reach the view model rather than merely exist.
    @Test("the failed empty state retries through the view model")
    func retryReachesTheViewModel() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = []
        viewModel.loadFailed = true

        await renderCarousel(viewModel)

        // Driven directly: tapping a `ContentUnavailableView` action means
        // walking a UIKit hierarchy for a button whose identity SwiftUI does not
        // promise, which would test the framework rather than this wiring.
        viewModel.retryLoad()

        #expect(viewModel.retryCallCount == 1)
    }

    /// The carousel claims a focus as soon as items arrive, without waiting for
    /// a scroll — otherwise the card below would sit blank under a circle the
    /// user is already looking at.
    @Test("the carousel reports its focus once items arrive")
    func theCarouselAnnouncesItsFocus() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = .catalogue

        await renderCarousel(viewModel)

        #expect(viewModel.selectedIds.first == "1")
    }

    /// A selection decided elsewhere — page 1 auto-selecting, a reload picking a
    /// new first location — moves the carousel rather than being overwritten by
    /// it. The reported focus is the selection, not item one.
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

    /// No type and no dimension is the state where the rows stack collapses
    /// entirely, leaving a name and a strip.
    @Test("the detail draws a location with no rows")
    func detailDrawsARowlessLocation() async {
        let viewModel = StubLocationDetailViewModel()
        viewModel.locations = [.make(id: "1", type: nil, dimension: nil, residents: .crowd)]
        viewModel.selectedId = "1"

        await renderDetail(viewModel)
    }

    // MARK: - Leaves

    /// The circle on its own, in both of the states it has and with a name that
    /// needs every one of its three lines.
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
        await render(LocationResidentsListView(residents: .crowd))
        await render(LocationResidentsListView(residents: []))
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

    /// `.loadMore` and `.loading` are one spinner, as on the characters footer:
    /// the item only exists once the lazy row has built it, so its being on
    /// screen already means a page is about to be — or is being — asked for.
    /// Asserted by walking the hosted hierarchy for the activity indicator
    /// `ProgressView` is backed by, which is the one thing about this view a
    /// layout pass alone cannot tell.
    @Test("the pagination item spins for a page waiting or in flight, and not otherwise")
    func paginationItemSpins() async {
        #expect(await hostsSpinner(LocationsCarouselPaginationItemView(footer: .loadMore, loadedCount: 1, loadNextPage: {})))
        #expect(await hostsSpinner(LocationsCarouselPaginationItemView(footer: .loading, loadedCount: 1, loadNextPage: {})))
        #expect(await !hostsSpinner(LocationsCarouselPaginationItemView(footer: .retry, loadedCount: 1, loadNextPage: {})))
        #expect(await !hostsSpinner(LocationsCarouselPaginationItemView(footer: .none, loadedCount: 1, loadNextPage: {})))
    }

    /// The item *is* the trigger: appearing is what asks for the page. A failed
    /// page must not — that is the Retry button's job, not something the row
    /// silently retries in a loop.
    @Test("the pagination item asks for the next page when it appears, unless it failed")
    func paginationItemLoadsOnAppearance() async {
        let calls = CallCounter()
        await render(LocationsCarouselPaginationItemView(footer: .loadMore, loadedCount: 20) { calls.increment() })
        #expect(calls.count == 1)

        let retryCalls = CallCounter()
        await render(LocationsCarouselPaginationItemView(footer: .retry, loadedCount: 20) { retryCalls.increment() })
        #expect(retryCalls.count == 0)
    }

    /// Through the whole section: a short first page leaves the pagination item
    /// inside the visible row from the first frame, so the lazy stack builds it
    /// and it asks for page two on its own — the carousel's version of the list
    /// footer's `.task(id: count)`.
    @Test("a short page asks for the next one without a scroll")
    func aShortPageLoadsTheNextOne() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = [.make(id: "1", name: "Earth (C-137)")]
        viewModel.selectedId = "1"
        viewModel.pagination = .idle(nextPage: 2)

        await renderCarousel(viewModel)

        #expect(viewModel.loadNextPageCallCount >= 1)
    }

    /// The end of the catalogue draws no item and asks for nothing.
    @Test("the end of the list asks for nothing")
    func theEndAsksForNothing() async {
        let viewModel = StubLocationsCarouselViewModel()
        viewModel.locations = [.make(id: "1", name: "Earth (C-137)")]
        viewModel.selectedId = "1"
        viewModel.pagination = .end

        await renderCarousel(viewModel)

        #expect(viewModel.loadNextPageCallCount == 0)
    }

    /// The helix no screen draws any more. It is kept compiled and tested — the
    /// projection in `SpiralGeometry` is worth keeping — so it is still hosted
    /// here over a list long enough to have items outside the visible span.
    @Test("the unused navigator draws with a selection well down the helix")
    func navigatorDraws() async {
        let items = (1...20).map { index in
            SpiralItem(id: "\(index)", title: "Location \(index)",
                       subtitle: index.isMultiple(of: 2) ? "Planet" : "",
                       symbol: "mappin")
        }

        await render(SpiralNavigator(items: items, selectedId: "12"))
    }

    /// An empty helix is what every index-from-an-offset calculation in there
    /// has to survive.
    @Test("the unused navigator draws with no items at all")
    func navigatorDrawsEmpty() async {
        await render(SpiralNavigator(items: [], selectedId: nil))
    }

    /// The card's preview shape draws the same content the section does, so it
    /// is worth a layout pass of its own.
    @Test("the detail preview card draws")
    func previewCardDraws() async {
        await render(LocationDetailSectionView.PreviewCard(content: LocationDetailContent(
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
                LocationsScreenGraph(viewModel: viewModel,
                                     carouselMapper: LocationsCarouselSectionMapper(viewModel: viewModel),
                                     detailMapper: LocationDetailSectionMapper(viewModel: viewModel))
            },
            makeSection: { graph in
                VStack {
                    LocationsCarouselSectionView(viewModel: graph.viewModel,
                                                 mapper: graph.carouselMapper)
                    LocationDetailSectionView(mapper: graph.detailMapper)
                }
            }
        )

        await render(screen)

        // The screen's `.task` is not guaranteed to have run by the time layout
        // returns, so the load is driven directly: what is under test here is
        // that the graph the screen was handed is wired to something that works,
        // and that the sections redraw when it answers.
        await viewModel.loadData()
        await settle()

        #expect(viewModel.locationsPublished?.map(\.id) == ["1-0", "1-1"])
        #expect(viewModel.selectedLocationIdPublished == "1-0")
    }

    /// The whole screen through the factory — carousel at its natural height,
    /// card underneath — on a repository that answers without a network. This is
    /// the one test that draws the two sections against each other in the frames
    /// they really get.
    @Test("the factory's screen draws both sections stacked")
    func factoryScreenDraws() async {
        await render(LocationsFactory.previewScreen(repository: StubViewsLocationsRepository()))
    }

    /// The public entry point, wired all the way down to a real repository over
    /// a real cache store. It reaches no network — the endpoint resolves to
    /// nothing — which is the point: what is under test is that the app's one
    /// call into this feature produces something that lays out.
    @Test("the feature's public entry point draws")
    func factoryBuildDraws() async {
        await render(LocationsFactory.build(dependencies: StubLocationsDependencies()))
    }

    // MARK: - Hosting

    private func renderCarousel(_ viewModel: StubLocationsCarouselViewModel) async {
        await render(LocationsCarouselSectionView(
            viewModel: viewModel,
            mapper: LocationsCarouselSectionMapper(viewModel: viewModel)
        ))
    }

    private func renderDetail(_ viewModel: StubLocationDetailViewModel) async {
        await render(LocationDetailSectionView(mapper: LocationDetailSectionMapper(viewModel: viewModel)))
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

        // A third pass, after another turn: the carousel's focus is claimed by
        // an `onChange` that runs once the items have been laid out, and the
        // `selectLocation` it triggers is the thing these tests assert on.
        await settle()

        window.layoutIfNeeded()
        window.isHidden = true
    }

    /// Hosts `view` and reports whether a `UIActivityIndicatorView` — what
    /// `ProgressView` is backed by on iOS — ended up in the hierarchy.
    /// The size `view` asks for at a phone's width, measured through the
    /// hosting controller rather than its `UIView` and with the safe area off,
    /// so the answer is the SwiftUI view's own size and not the window's insets
    /// added to it.
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

    /// Yields the main thread long enough for the main-queue delivery in
    /// `SectionMapperContract.renderModelPublisher()` to land.
    private func settle() async {
        for _ in 0..<10 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(20))
    }
}

private extension Array where Element == LocationModel {
    /// Twelve locations: more than fit across the screen at once, so the
    /// carousel really scrolls and the last-three rule has room to be false.
    static var catalogue: [LocationModel] {
        (1...12).map { index in
            LocationModel.make(id: "\(index)",
                               name: "Location \(index)",
                               type: index.isMultiple(of: 3) ? nil : "Planet",
                               dimension: "Dimension C-\(index)")
        }
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
    /// Depth-first over the whole hierarchy, `self` included.
    func contains(where predicate: (UIView) -> Bool) -> Bool {
        predicate(self) || subviews.contains { $0.contains(where: predicate) }
    }
}

/// A call count the test can read back from a `@Sendable` closure.
@MainActor
final class CallCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}
