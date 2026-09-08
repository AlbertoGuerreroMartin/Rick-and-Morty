//
//  SpiralGeometryTests.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import CoreGraphics
import Foundation
import Testing
@testable import Locations

/// The helix's maths, pulled out of the view so it can be checked as arithmetic
/// rather than as pixels.
///
/// None of these assert an exact coordinate — the numbers are a look, and pinning
/// them would make every tweak to the shape a failing test. What they pin is the
/// *contract*: the focus is the origin, the helix is symmetric about it, things
/// fade out at the edge of the span rather than popping, an index is always a
/// real index, and the ends resist instead of stopping dead.
@Suite("SpiralGeometry")
struct SpiralGeometryTests {

    private let geometry = SpiralGeometry()

    // MARK: - Projection

    /// `t = 0` is whatever is centred, so the whole projection is written once
    /// and the offset is subtracted by the caller. If this drifted, every sphere
    /// on the helix would be off by the same amount and the caption would name
    /// the wrong one.
    @Test("the focus projects to the centre, nearest the viewer")
    func focusIsTheOrigin() {
        let node = geometry.project(0)

        #expect(node.x.isApproximately(0))
        #expect(node.y.isApproximately(0))
        // Straight at the camera: depth is +1 and the perspective scale is
        // greater than 1 because the item is closer than the axis.
        #expect(node.depth.isApproximately(1))
        #expect(node.scale > 1)
    }

    @Test("an item further along sits lower and smaller")
    func itemsFurtherAlongSinkAway() {
        let near = geometry.project(0)
        let far = geometry.project(3)

        #expect(far.y > near.y)
        #expect(far.scale < near.scale)
    }

    /// A helix is symmetric about its focus: the item one step up and the item
    /// one step down are mirror images, which is what makes the wire read as a
    /// single continuous curve rather than two.
    @Test("the helix is symmetric about the focus")
    func projectionIsSymmetric() {
        let up = geometry.project(-2)
        let down = geometry.project(2)

        #expect(up.x.isApproximately(-down.x))
        #expect(up.y.isApproximately(-down.y))
        #expect(up.depth.isApproximately(down.depth))
        #expect(up.scale.isApproximately(down.scale))
    }

    /// Half a turn of 42° each is a little over four items, so an item on the far
    /// side has negative depth — which is what the shading and the z-ordering
    /// read to put it behind the axis.
    @Test("an item on the far side of the axis has negative depth")
    func theFarSideIsBehindTheAxis() {
        #expect(geometry.project(3).depth < 0)
    }

    /// The guard against a divide by zero: a focal length shorter than the radius
    /// would otherwise put a sphere behind the camera and send its scale to
    /// infinity.
    @Test("an absurd focal length still produces a finite scale")
    func aShortFocalLengthDoesNotDivideByZero() {
        let extreme = SpiralGeometry(config: SpiralConfig(radius: 105, focal: 100))

        #expect(extreme.project(0).scale.isFinite)
    }

    // MARK: - Fade

    @Test("the fade is 1 at the focus and 0 at the edge of the span")
    func fadeSpansTheVisibleRange() {
        #expect(geometry.fade(at: 0).isApproximately(1))
        #expect(geometry.fade(at: geometry.config.visibleSpan).isApproximately(0))
        #expect(geometry.fade(at: -geometry.config.visibleSpan).isApproximately(0))
    }

    /// Clamped rather than allowed to go negative: the opacity it drives is
    /// squared at the call site, and a negative fade would square back into a
    /// sphere reappearing beyond the edge of the span.
    @Test("the fade never goes below zero past the span")
    func fadeIsClampedPastTheSpan() {
        #expect(geometry.fade(at: 20) == 0)
        #expect(geometry.fade(at: -20) == 0)
    }

    @Test("the fade is symmetric and decreasing")
    func fadeIsSymmetric() {
        #expect(geometry.fade(at: 2).isApproximately(geometry.fade(at: -2)))
        #expect(geometry.fade(at: 1) > geometry.fade(at: 2))
    }

    // MARK: - The focused index

    @Test("the focused index is the nearest item")
    func focusedIndexRounds() {
        #expect(geometry.focusedIndex(at: 0, count: 5) == 0)
        #expect(geometry.focusedIndex(at: 2.4, count: 5) == 2)
        #expect(geometry.focusedIndex(at: 2.6, count: 5) == 3)
    }

    /// A rubber-banded overshoot still has to name a real item, or the caption
    /// would index past the end of the array.
    @Test("an overshoot still names a real item")
    func focusedIndexIsClamped() {
        #expect(geometry.focusedIndex(at: -1.8, count: 5) == 0)
        #expect(geometry.focusedIndex(at: 9, count: 5) == 4)
    }

    @Test("an empty helix has no index to fall off")
    func focusedIndexOnAnEmptyHelix() {
        #expect(geometry.focusedIndex(at: 3, count: 0) == 0)
        #expect(geometry.isSettled(at: 0, count: 0) == false)
    }

    /// Mid-flight the caption would be a blur nobody can read, so it only appears
    /// once the helix is close enough to an item.
    @Test("the caption appears only near an item")
    func settlingIsNearAnItem() {
        #expect(geometry.isSettled(at: 2, count: 5))
        #expect(geometry.isSettled(at: 2.2, count: 5))
        #expect(!geometry.isSettled(at: 2.5, count: 5))
    }

    // MARK: - Clamping and the rubber band

    @Test("clamping keeps a value inside the list")
    func clampingKeepsTheValueInRange() {
        #expect(geometry.clampedIndex(-3, count: 5).isApproximately(0))
        #expect(geometry.clampedIndex(2, count: 5).isApproximately(2))
        #expect(geometry.clampedIndex(9, count: 5).isApproximately(4))
        #expect(geometry.clampedIndex(9, count: 0).isApproximately(0))
    }

    @Test("the rubber band leaves the middle of the helix alone")
    func rubberBandIsIdentityInTheMiddle() {
        #expect(geometry.rubberBanded(2.5, count: 5).isApproximately(2.5))
        #expect(geometry.rubberBanded(0, count: 5).isApproximately(0))
    }

    /// Past the top, the drag still moves — it just moves less. The overshoot is
    /// there and smaller than what was asked for, which is what "resists" means.
    @Test("the rubber band resists past the top")
    func rubberBandResistsAtTheTop() {
        let banded = geometry.rubberBanded(-4, count: 5)

        #expect(banded < 0)
        #expect(banded > -4)
    }

    @Test("the rubber band resists past the bottom")
    func rubberBandResistsAtTheBottom() {
        let last: CGFloat = 4
        let banded = geometry.rubberBanded(last + 4, count: 5)

        #expect(banded > last)
        #expect(banded < last + 4)
    }

    /// The exponent below 1 is the whole feel of the end: the further you pull,
    /// the less each point of drag buys.
    @Test("resistance grows the further the overshoot goes")
    func resistanceGrows() {
        let small = geometry.rubberBanded(-1, count: 5)
        let large = geometry.rubberBanded(-9, count: 5)

        // Nine times the pull, nowhere near nine times the movement.
        #expect(abs(large) > abs(small))
        #expect(abs(large) < 9 * abs(small))
    }

    @Test("an empty helix cannot be dragged anywhere")
    func rubberBandOnAnEmptyHelix() {
        #expect(geometry.rubberBanded(7, count: 0).isApproximately(0))
    }

    // MARK: - The visible span

    /// The wire is drawn only where there are items to thread on it, so the
    /// helix does not run off past the first and the last sphere.
    @Test("the visible span is cut back to the items that exist")
    func visibleSpanIsCutBackToTheItems() throws {
        let span = try #require(geometry.visibleSpan(offset: 0, count: 3))

        #expect(span.lo.isApproximately(0))
        #expect(span.hi.isApproximately(2))
    }

    @Test("in the middle of a long helix the whole span is drawn")
    func visibleSpanIsTheWholeRangeInTheMiddle() throws {
        let span = try #require(geometry.visibleSpan(offset: 20, count: 100))

        #expect(span.lo.isApproximately(-geometry.config.visibleSpan))
        #expect(span.hi.isApproximately(geometry.config.visibleSpan))
    }

    @Test("there is nothing to draw for an empty or single-item helix")
    func visibleSpanIsNilWhenThereIsNothingToDraw() {
        #expect(geometry.visibleSpan(offset: 0, count: 0) == nil)
        #expect(geometry.visibleSpan(offset: 0, count: 1) == nil)
    }
}

private extension CGFloat {
    /// Trigonometry and `pow` do not produce exact decimals, and none of these
    /// tests are about the last bit of a `Double`.
    func isApproximately(_ other: CGFloat, tolerance: CGFloat = 0.0001) -> Bool {
        abs(self - other) < tolerance
    }
}
