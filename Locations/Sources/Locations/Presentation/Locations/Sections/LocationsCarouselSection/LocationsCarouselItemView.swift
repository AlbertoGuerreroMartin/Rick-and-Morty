//
//  LocationsCarouselItemView.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import SwiftUI

/// One stop on the carousel: a lit yellow sphere with the location's name in it.
///
/// The sphere itself is `LocationsCarouselCircleView`, shared with the
/// pagination item at the end of the row so the two cannot drift apart; this
/// view only adds the name. It is roughly two and a half times the helix
/// sphere's diameter, because it carries text instead of a pin.
struct LocationsCarouselItemView: View {

    /// The circle's diameter, in points. Big enough for three lines of a
    /// headline at the default text size, which covers all but a handful of the
    /// catalogue's longest names.
    static let diameter: CGFloat = 150

    let title: String
    /// Whether this is the item at the centre of the carousel. Only the glow
    /// reads it: the scale and the dimming are driven by the scroll itself in
    /// `LocationsCarouselSectionView`, so they follow a drag continuously rather
    /// than snapping when the focus finally settles.
    let isFocused: Bool
    var diameter: CGFloat = LocationsCarouselItemView.diameter

    var body: some View {
        ZStack {
            LocationsCarouselCircleView(isFocused: isFocused, diameter: diameter)
            name
        }
        // The frame is on the stack, not only on the circle inside it: it is
        // what proposes the circle's width to the text, and a `Text` proposed
        // nothing lays a long name out on one line straight past the rim.
        .frame(width: diameter, height: diameter)
        // One element saying the name, because that is the whole item: the
        // sphere is decoration and the four gradients inside it are not
        // something VoiceOver should stop on.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isFocused ? [.isButton, .isSelected] : .isButton)
    }

    /// Dark text, fixed rather than following light or dark mode: the backdrop
    /// here is the yellow, not the screen, and black-on-yellow is the pair that
    /// stays legible in both. The same reasoning as the characters grid's white
    /// captions over their images.
    private var name: some View {
        Text(title)
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.black.opacity(0.78))
            .multilineTextAlignment(.center)
            // Three lines, then shrink: a name is what identifies the stop, so
            // truncating it to an ellipsis would leave the user scrolling past
            // circles they cannot tell apart. Below 0.7 it stops being readable
            // at arm's length, and the card below has the name in full anyway.
            .lineLimit(3)
            .minimumScaleFactor(0.7)
            // Kept off the rim: text laid against the edge of a circle reads as
            // spilling out of it.
            .padding(.horizontal, diameter * 0.15)
    }
}

/// The yellow sphere every stop on the carousel is drawn on — the one with a
/// name in it and the empty one with a spinner at the end of the row.
///
/// The look is the helix's sphere, kept on purpose — the same tint, the same
/// off-centre light, the same rim and specular highlight — because that sphere
/// is what this screen looked like and the carousel is a different *control*,
/// not a different theme. One thing had to change with the backdrop, though.
/// The helix drew its spheres over a near-black radial gradient, so their body
/// could fade to almost nothing at the edge; on the system background a circle
/// that faded out would dissolve into the page in light mode and float in dark.
/// So the body is opaque and the shading is painted *over* it — a white wash on
/// the lit side and a soft terminator on the other — which reads as the same
/// sphere on either background.
struct LocationsCarouselCircleView: View {

    /// The sphere's yellow, straight from `SphereNode`.
    private static let tint = Color(red: 246 / 255, green: 233 / 255, blue: 68 / 255)

    /// Whether this is the item at the centre of the carousel. It drives the
    /// glow, and nothing else.
    let isFocused: Bool
    var diameter: CGFloat = LocationsCarouselItemView.diameter

    var body: some View {
        ZStack {
            // Body. Opaque, unlike the helix's — see the note above.
            Circle()
                .fill(Self.tint)
            // The lit side: an off-centre white wash, the same centre the helix
            // used, which is what reads as a sphere rather than a disc.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.55), .white.opacity(0.0)],
                        center: UnitPoint(x: 0.33, y: 0.28),
                        startRadius: 1,
                        endRadius: diameter * 0.78
                    )
                )
            // The terminator: the far side falling into shadow. Starting the
            // gradient well out from the light keeps the darkening at the rim
            // instead of muddying the middle.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.black.opacity(0.0), .black.opacity(0.22)],
                        center: UnitPoint(x: 0.33, y: 0.28),
                        startRadius: diameter * 0.34,
                        endRadius: diameter * 0.78
                    )
                )
            // Rim light
            Circle()
                .strokeBorder(.white.opacity(0.3), lineWidth: 0.8)
            // Specular highlight
            Circle()
                .fill(.white.opacity(0.5))
                .frame(width: diameter * 0.17, height: diameter * 0.17)
                .offset(x: -diameter * 0.18, y: -diameter * 0.21)
                .blur(radius: diameter * 0.055)
        }
        .frame(width: diameter, height: diameter)
        // The glow the helix gave its focused sphere, and the only thing here
        // that says which item the card below is describing once the scroll has
        // stopped moving.
        .shadow(color: Self.tint.opacity(isFocused ? 0.7 : 0.3),
                radius: isFocused ? 20 : 8)
    }
}

#Preview("Focused and not") {
    HStack(spacing: 24) {
        LocationsCarouselItemView(title: "Earth (C-137)", isFocused: true)
        LocationsCarouselItemView(title: "Abadango", isFocused: false)
    }
    .padding(40)
}

#Preview("A name that barely fits") {
    LocationsCarouselItemView(title: "Interdimensional Cable Broadcasting Station",
                              isFocused: true)
        .padding(40)
}
