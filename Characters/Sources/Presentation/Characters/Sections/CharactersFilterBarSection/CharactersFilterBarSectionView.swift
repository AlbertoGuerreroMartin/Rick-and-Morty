//
//  CharactersFilterBarSectionView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

import Combine
import Core
import SwiftUI

/// The strip of capsules under the search bar; always visible, as the only entry point to the filter sheet.
struct CharactersFilterBarSectionView: SectionViewContract {
    /// Held as the contract, not observed directly.
    let viewModel: any CharactersFilterBarSectionViewModelContract

    let renderModelPublisher: AnyPublisher<CharactersFilterBarRenderModel, Never>

    @State private var renderModel: CharactersFilterBarRenderModel = .empty

    /// The view's own state: nothing outside this bar opens the sheet.
    @State private var isPresentingFilters = false

    init(viewModel: any CharactersFilterBarSectionViewModelContract,
         renderModelPublisher: AnyPublisher<CharactersFilterBarRenderModel, Never>) {
        self.viewModel = viewModel
        self.renderModelPublisher = renderModelPublisher
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                filtersButton
                ForEach(renderModel.chips) { chip in
                    chipView(chip)
                }
                if renderModel.activeCount > 0 {
                    Button {
                        viewModel.clearAllFilters()
                    } label: {
                        Text("Clear all", bundle: .module)
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .onReceive(renderModelPublisher) {
            renderModel = $0
        }
        .sheet(isPresented: $isPresentingFilters) {
            // Seeded from the applied filter every time it opens.
            CharactersFilterSheet(initial: renderModel.filter) { filter in
                viewModel.apply(filter)
            }
        }
    }

    /// The count lives in the label, not a badge, so it survives Dynamic Type and reads via VoiceOver.
    private var filtersButton: some View {
        Button {
            isPresentingFilters = true
        } label: {
            Label {
                if renderModel.activeCount > 0 {
                    Text("Filters · \(renderModel.activeCount)", bundle: .module)
                } else {
                    Text("Filters", bundle: .module)
                }
            } icon: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .font(.subheadline)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
    }

    private func chipView(_ chip: CharactersFilterChip) -> some View {
        Button {
            viewModel.clear(chip.field)
        } label: {
            HStack(spacing: 4) {
                Text(chip.title)
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.small)
            }
            .font(.subheadline)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .accessibilityLabel(Text("Remove \(chip.title) filter", bundle: .module))
    }
}
