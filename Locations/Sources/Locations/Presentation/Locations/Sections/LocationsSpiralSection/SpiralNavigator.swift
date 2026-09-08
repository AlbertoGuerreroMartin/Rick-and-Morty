//
//  SpiralNavigator.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import SwiftUI

// MARK: - Model

/// One sphere on the helix.
///
/// The `id` is an explicit `String` rather than a generated `UUID`. That is the
/// difference between a decorative control and one a screen can be driven by:
/// the helix reports the item that settled at the focus, the view model
/// publishes it back as the selection, and both halves have to be talking about
/// the same location — which a fresh `UUID` per rebuild could not do, because
/// SwiftUI rebuilds this value on every body evaluation.
struct SpiralItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
}

// MARK: - Geometry configuration

/// The shape of the helix. Every number here is a look, not a rule, which is why
/// they sit in a value the view takes rather than as constants inside it.
struct SpiralConfig: Equatable {
    /// Radius of the helix, in points.
    var radius: CGFloat = 105
    /// Vertical distance between two consecutive items (the helix pitch per item).
    var pitch: CGFloat = 54
    /// Rotation around the axis between two consecutive items, in degrees.
    var turn: CGFloat = 42
    /// Camera focal length. Smaller = more dramatic perspective.
    var focal: CGFloat = 560
    /// Diameter of a sphere at scale 1.
    var sphereSize: CGFloat = 58
    /// How many items away from the focus are still (faintly) visible.
    var visibleSpan: CGFloat = 5.5
}

/// A point on the helix, already projected to screen space.
struct SpiralNode: Equatable {
    /// Offset from the screen centre.
    var x: CGFloat
    /// Offset from the screen centre.
    var y: CGFloat
    /// Perspective scale (> 1 = closer than the axis).
    var scale: CGFloat
    /// -1 (far side) ... +1 (near side).
    var depth: CGFloat
}

// MARK: - Geometry

/// Where every sphere goes, how solid it looks, and what a drag does to the
/// position along the helix.
///
/// **Extracted from the view on purpose.** All of this is arithmetic — a
/// perspective projection, a linear fade, a clamp and a rubber band — and
/// arithmetic buried in a SwiftUI `body` can only be checked by looking at
/// pixels. As a value it is a handful of pure functions with an obvious contract:
/// `project(0)` is the focus, the helix is symmetric about it, the fade reaches
/// zero at the edge of the visible span, and the ends resist instead of stopping
/// dead. `SpiralGeometryTests` asserts each of those directly.
///
/// There is no SceneKit here and there does not need to be: this is one sine,
/// one cosine and a division per sphere, run over the dozen items that are
/// actually visible.
struct SpiralGeometry: Equatable {
    let config: SpiralConfig

    init(config: SpiralConfig = SpiralConfig()) {
        self.config = config
    }

    /// Projects the helix parameter `t` — the item index *relative to the focus*
    /// — into screen space.
    ///
    /// `t = 0` is whatever is centred, so the whole projection is written once
    /// and the offset is subtracted by the caller. `+z` points at the viewer,
    /// which is what makes `scale` grow as an item comes round the near side and
    /// `depth` the number the shading and the z-ordering are read from.
    func project(_ t: CGFloat) -> SpiralNode {
        let theta = t * config.turn * .pi / 180
        let x3 = config.radius * sin(theta)
        let z3 = config.radius * cos(theta)
        let y3 = t * config.pitch
        // `max(..., 1)` is the divide-by-zero guard: a focal length shorter than
        // the radius would otherwise put a sphere *behind* the camera and send
        // its scale to infinity.
        let scale = config.focal / max(config.focal - z3, 1)
        return SpiralNode(x: x3 * scale,
                          y: y3 * scale,
                          scale: scale,
                          depth: z3 / config.radius)
    }

    /// 1 at the focus, 0 at the edge of the visible span.
    ///
    /// Linear rather than a curve: the opacity it drives is squared at the call
    /// site, which is what gives the falloff its shape. Two curves multiplied
    /// together would be one knob nobody could reason about.
    func fade(at t: CGFloat) -> CGFloat {
        max(0, 1 - abs(t) / config.visibleSpan)
    }

    /// Which item is at the focus for a given offset. Clamped, so a rubber-banded
    /// overshoot still names a real item.
    func focusedIndex(at offset: CGFloat, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(Int(offset.rounded()), 0), count - 1)
    }

    /// Whether the helix has come close enough to an item for its caption to be
    /// worth showing. Mid-flight the text would be a blur nobody can read.
    func isSettled(at offset: CGFloat, count: Int) -> Bool {
        guard count > 0 else { return false }
        return abs(offset - CGFloat(focusedIndex(at: offset, count: count))) < 0.45
    }

    func clampedIndex(_ value: CGFloat, count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return min(max(value, 0), CGFloat(count - 1))
    }

    /// Lets the helix overshoot its ends with resistance instead of stopping
    /// dead.
    ///
    /// The exponent is what makes it feel like a physical end: below 1 the
    /// derivative falls as the overshoot grows, so the first few points of drag
    /// move nearly as far as they would in the middle and the next hundred
    /// barely move at all.
    func rubberBanded(_ value: CGFloat, count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let hi = CGFloat(count - 1)
        if value < 0 { return -pow(-value, 0.6) }
        if value > hi { return hi + pow(value - hi, 0.6) }
        return value
    }

    /// The stretch of helix worth drawing the wire for: the visible span, cut
    /// back to the items that actually exist. `nil` when there is nothing to
    /// draw.
    func visibleSpan(offset: CGFloat, count: Int) -> (lo: CGFloat, hi: CGFloat)? {
        guard count > 0 else { return nil }
        let lo = max(-config.visibleSpan, -offset)
        let hi = min(config.visibleSpan, CGFloat(count - 1) - offset)
        guard hi > lo else { return nil }
        return (lo, hi)
    }
}

// MARK: - Main view

/// A 3D helix — a "spiral staircase" — of spheres, built in pure SwiftUI.
///
/// **No screen uses this.** The Locations screen drew its locations on this
/// helix and now draws them on a stepped carousel instead — a helix is a lovely
/// thing to look at and a poor thing to find a place in, since reaching item 90
/// means dragging past 89 of them and nothing on it says how far along you are.
/// It is kept, compiled and tested rather than deleted: the projection in
/// `SpiralGeometry` is the interesting half and it is correct, so it costs
/// nothing to keep and would cost an afternoon to write again. Nothing outside
/// this file refers to it.
///
/// Dragging vertically moves every sphere along the skeleton: items rise, rotate
/// around the axis and sink away behind it. Whatever settles at the centre is
/// the focus, and the focus *is* the selection — the view reports it and the
/// screen decides what that means.
///
/// **It navigates nothing.** The version this grew out of owned a
/// `NavigationStack` and pushed a detail of its own; here the detail is a
/// section sitting under it in the same screen, and a stack inside a section
/// would put a second navigation hierarchy inside the screen's own. What is left
/// is a control: items in, a focused id out.
///
/// Two inputs make it usable by a paginated screen. `selectedId` moves the focus
/// when the selection changes from outside — a reload, or a screen restoring
/// itself — and `onFocusChange` reports the index that settled, from a drag, a
/// tap, or the first frame after items arrive. Appending items deliberately does
/// **not** move the offset: a page landing while the user is halfway down the
/// helix must not teleport them back to the top.
///
/// Fast-scroll polish is out of scope: a long flick settles on whatever the
/// predicted end lands on, and the helix does not try to be clever about it.
struct SpiralNavigator: View {

    let items: [SpiralItem]
    /// The item that should be at the focus, when something outside decides it.
    var selectedId: String?
    /// Called with the index that settled at the focus.
    var onFocusChange: (Int) -> Void = { _ in }
    var config = SpiralConfig()

    /// Continuous position along the helix. `offset == 2.0` means item 2 is
    /// focused.
    @State private var offset: CGFloat = 0
    /// Value of `offset` when the current drag began.
    @State private var dragAnchor: CGFloat?
    /// Whether the first arrival of items has been reported. The helix always
    /// has something at its centre, so the screen is told what that is without
    /// waiting for a gesture the user has no reason to make.
    @State private var hasAnnouncedFocus = false

    private var geometry: SpiralGeometry {
        SpiralGeometry(config: config)
    }

    private var focusedIndex: Int {
        geometry.focusedIndex(at: offset, count: items.count)
    }

    private var isFocusSettled: Bool {
        geometry.isSettled(at: offset, count: items.count)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backdrop
                skeleton(in: geo.size)
                spheres(in: geo.size)
                caption
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)
        }
        // `initial: true` so a helix that is built with items already in hand —
        // which is every rebuild after the first page — reports its focus too.
        .onChange(of: items.count, initial: true) { _, _ in
            itemsChanged()
        }
        .onChange(of: selectedId, initial: true) { _, id in
            moveFocus(to: id)
        }
    }

    // MARK: Layers

    private var backdrop: some View {
        RadialGradient(
            colors: [Color(red: 0.09, green: 0.10, blue: 0.16),
                     Color(red: 0.03, green: 0.03, blue: 0.06)],
            center: .center, startRadius: 40, endRadius: 520
        )
    }

    /// The wire the spheres are threaded on. Drawn per-segment so line weight and
    /// brightness track depth — that alone reads as 3D before the spheres land.
    private func skeleton(in size: CGSize) -> some View {
        Canvas { ctx, canvas in
            let cx = canvas.width / 2, cy = canvas.height / 2
            guard let span = geometry.visibleSpan(offset: offset, count: items.count) else { return }

            var samples: [(pt: CGPoint, depth: CGFloat, fade: CGFloat)] = []
            var t = span.lo
            while t <= span.hi {
                let node = geometry.project(t)
                samples.append((CGPoint(x: cx + node.x, y: cy + node.y),
                                node.depth,
                                geometry.fade(at: t)))
                t += 0.06
            }

            guard samples.count > 1 else { return }

            for index in 1..<samples.count {
                let a = samples[index - 1], b = samples[index]
                var segment = Path()
                segment.move(to: a.pt)
                segment.addLine(to: b.pt)
                let depth = (a.depth + b.depth) / 2
                let fade = (a.fade + b.fade) / 2
                let near = (depth + 1) / 2
                ctx.stroke(segment,
                           with: .color(.white.opacity((0.06 + 0.26 * near) * fade)),
                           lineWidth: 0.8 + 1.8 * near)
            }
        }
        .allowsHitTesting(false)
    }

    private func spheres(in size: CGSize) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            let t = CGFloat(index) - offset
            let node = geometry.project(t)
            let fade = geometry.fade(at: t)
            let focus = max(0, 1 - abs(t))

            SphereNode(item: item,
                       size: config.sphereSize,
                       focus: focus,
                       depth: node.depth)
                .scaleEffect(node.scale * (1 + 0.22 * focus))
                .position(x: size.width / 2 + node.x,
                          y: size.height / 2 + node.y)
                .opacity(Double(fade * fade))
                .blur(radius: (1 - fade) * 5 + max(0, -node.depth) * 1.4)
                .zIndex(Double(node.depth))
                // A sphere faded almost to nothing is still a hit target, and
                // tapping one the user cannot see would look like the helix
                // jumped on its own.
                .allowsHitTesting(fade > 0.15)
                .onTapGesture { handleTap(index) }
        }
    }

    @ViewBuilder
    private var caption: some View {
        VStack(spacing: 4) {
            Spacer()
            if isFocusSettled, items.indices.contains(focusedIndex) {
                Text(items[focusedIndex].title)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(items[focusedIndex].subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))
                    .transition(.opacity)
            }
            // "tap to open" is gone with the navigation it described: a tap now
            // brings a sphere to the focus and nothing more, and promising a
            // screen that does not exist is worse than saying less.
            Text("drag to travel")
                .font(.caption2.smallCaps())
                .foregroundStyle(.white.opacity(0.3))
                .padding(.top, 14)
        }
        .padding(.bottom, 44)
        .animation(.easeOut(duration: 0.18), value: focusedIndex)
        .animation(.easeOut(duration: 0.18), value: isFocusSettled)
        .allowsHitTesting(false)
    }

    // MARK: Interaction

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragAnchor == nil { dragAnchor = offset }
                // Dragging up (negative height) advances along the helix.
                let raw = (dragAnchor ?? 0) - value.translation.height / config.pitch
                offset = geometry.rubberBanded(raw, count: items.count)
            }
            .onEnded { value in
                let base = dragAnchor ?? offset
                dragAnchor = nil
                // `predictedEndTranslation` gives flick momentum for free.
                let predicted = base - value.predictedEndTranslation.height / config.pitch
                let target = geometry.clampedIndex(predicted.rounded(), count: items.count)
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                    offset = target
                }
                settle(on: Int(target))
            }
    }

    /// Tapping the focused sphere does nothing.
    ///
    /// It used to open a detail; there is nothing to open now, and a tap that
    /// re-published the selection it already holds would be a no-op the user
    /// could still feel, because it would re-run the animation. Tapping any
    /// *other* sphere brings it to the focus, which is the fast way past a
    /// dozen items.
    private func handleTap(_ index: Int) {
        guard abs(CGFloat(index) - offset) >= 0.5 else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
            offset = CGFloat(index)
        }
        settle(on: index)
    }

    private func settle(on index: Int) {
        guard items.indices.contains(index) else { return }
        onFocusChange(index)
    }

    /// Moves the helix when the selection was decided somewhere else.
    ///
    /// Guarded on the distance rather than on the id, because the common case is
    /// this view's *own* focus change coming back round through the view model:
    /// the offset is already there, and animating to where it is would fight the
    /// spring that just put it there.
    private func moveFocus(to id: String?) {
        guard let id, let index = items.firstIndex(where: { $0.id == id }) else { return }
        let target = CGFloat(index)
        guard abs(offset - target) > 0.01 else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
            offset = target
        }
    }

    /// Items arrived, or more of them did.
    ///
    /// **Appending never moves the offset**, which is the whole reason this is
    /// not simply `offset = 0`: page 2 landing while the user is at item 18 must
    /// leave them at item 18. The clamp is for the other direction — a list that
    /// came back *shorter* would otherwise leave the focus past its end.
    private func itemsChanged() {
        guard !items.isEmpty else {
            offset = 0
            hasAnnouncedFocus = false
            return
        }

        let clamped = geometry.clampedIndex(offset, count: items.count)
        if clamped != offset { offset = clamped }

        guard !hasAnnouncedFocus else { return }
        hasAnnouncedFocus = true
        settle(on: focusedIndex)
    }
}

// MARK: - Sphere

struct SphereNode: View {
    let item: SpiralItem
    let size: CGFloat
    /// 0 ... 1, where 1 is dead centre.
    let focus: CGFloat
    /// -1 (far side) ... +1 (near side).
    let depth: CGFloat

    private let tint = Color(red: 246 / 255, green: 233 / 255, blue: 68 / 255)

    var body: some View {
        ZStack {
            // Body: an off-centre radial gradient reads as a lit sphere with no
            // 3D engine behind it.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.98),
                                 tint.opacity(0.52),
                                 tint.opacity(0.06)],
                        center: UnitPoint(x: 0.33, y: 0.28),
                        startRadius: 1,
                        endRadius: size * 0.95
                    )
                )
            // Rim light
            Circle()
                .strokeBorder(.white.opacity(0.26), lineWidth: 0.8)
            // Specular highlight
            Circle()
                .fill(.white.opacity(0.5))
                .frame(width: size * 0.17, height: size * 0.17)
                .offset(x: -size * 0.18, y: -size * 0.21)
                .blur(radius: size * 0.055)

            Image(systemName: item.symbol)
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
        }
        .frame(width: size, height: size)
        // Far side of the helix sits in shadow.
        .overlay(Circle().fill(.black.opacity(Double(max(0, -depth) * 0.35))))
        .shadow(color: tint.opacity(0.55 * Double(0.3 + focus)),
                radius: 6 + 14 * focus)
    }
}

// MARK: - Preview

private extension SpiralItem {
    /// Canvas-only sample data. The real items come from the section mapper.
    static let sample: [SpiralItem] = [
        "Earth (C-137)", "Abadango", "Citadel of Ricks", "Worldender's lair",
        "Anatomy Park", "Interdimensional Cable", "Purge Planet", "Venzenulon 7",
        "Bepis 9"
    ].enumerated().map { index, name in
        SpiralItem(id: "\(index + 1)", title: name, subtitle: "Planet", symbol: "mappin")
    }
}

#Preview {
    SpiralNavigator(items: SpiralItem.sample, selectedId: "1")
        .preferredColorScheme(.dark)
}
