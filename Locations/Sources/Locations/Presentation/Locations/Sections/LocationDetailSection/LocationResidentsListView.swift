//
//  LocationResidentsListView.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import DesignSystem
import SwiftUI

struct LocationResidentsListView: View {
    @Environment(\.displayScale) private var displayScale

    private static let avatarSize: CGFloat = 50

    /// Pixel size the downsampler decodes to, avoiding a full-size bitmap per resident.
    private var avatarPixelSize: CGFloat {
        Self.avatarSize * displayScale
    }

    let residents: [LocationResidentModel]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Residents")
                .font(.title3.weight(.semibold))
                .lineLimit(2)
            List {
                // Rows are `NavigationLink`s: dead unless a `NavigationStack` is above this view.
                ForEach(residents) { resident in
                    NavigationLink(value: LocationsRoute.character(id: resident.id)) {
                        HStack {
                            CachedAsyncImage(url: resident.image, maxPixelSize: avatarPixelSize) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(.quaternary)
                            }
                            .frame(width: Self.avatarSize, height: Self.avatarSize)
                            .clipShape(Circle())
                            .padding(.trailing)

                            Text(resident.name)
                                .font(.subheadline.weight(.medium))
                                .multilineTextAlignment(.trailing)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}
