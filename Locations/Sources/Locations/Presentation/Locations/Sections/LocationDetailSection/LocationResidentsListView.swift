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

    /// The avatar's rendered edge, in points.
    private static let avatarSize: CGFloat = 50

    /// The avatar edge in *pixels*, which is what the downsampler decodes to.
    /// Decoding at point size would be soft on every device shipped this decade;
    /// decoding at the source's own size would hold a 300x300 bitmap for each of
    /// the hundreds of residents a location can have.
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
                ForEach(residents) { resident in
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
                }
            }
            .listStyle(.inset)
        }
    }
}
