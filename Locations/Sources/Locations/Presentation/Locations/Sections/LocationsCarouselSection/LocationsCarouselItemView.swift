//
//  LocationsCarouselItemView.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import SwiftUI

/// One stop on the carousel: a lit yellow sphere with the location's name in it.
struct LocationsCarouselItemView: View {

    /// Big enough for three lines of a headline, covering all but the catalogue's longest names.
    static let diameter: CGFloat = 130

    let title: String
    /// Drives only the glow; scale and dimming follow the scroll itself in the section view.
    let isFocused: Bool
    var diameter: CGFloat = LocationsCarouselItemView.diameter

    var body: some View {
        ZStack {
            LocationsCarouselCircleView(isFocused: isFocused, diameter: diameter)
            name
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isFocused ? [.isButton, .isSelected] : .isButton)
    }

    private var name: some View {
        Text(title)
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.black.opacity(0.78))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, diameter * 0.15)
    }
}

/// The yellow sphere every carousel stop is drawn on. Opaque body with shading painted over it
/// (unlike the helix's fade-to-transparent version), so it reads the same on light and dark backgrounds.
struct LocationsCarouselCircleView: View {

    private static let tint = Color(red: 246 / 255, green: 233 / 255, blue: 68 / 255)

    let isFocused: Bool
    var diameter: CGFloat = LocationsCarouselItemView.diameter

    var body: some View {
        ZStack {
            Circle()
                .fill(Self.tint)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.55), .white.opacity(0.0)],
                        center: UnitPoint(x: 0.33, y: 0.28),
                        startRadius: 1,
                        endRadius: diameter * 0.78
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.black.opacity(0.0), .black.opacity(0.22)],
                        center: UnitPoint(x: 0.33, y: 0.28),
                        startRadius: diameter * 0.34,
                        endRadius: diameter * 0.78
                    )
                )
            Circle()
                .strokeBorder(.white.opacity(0.3), lineWidth: 0.8)
            Circle()
                .fill(.white.opacity(0.5))
                .frame(width: diameter * 0.17, height: diameter * 0.17)
                .offset(x: -diameter * 0.18, y: -diameter * 0.21)
                .blur(radius: diameter * 0.055)
        }
        .frame(width: diameter, height: diameter)
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
