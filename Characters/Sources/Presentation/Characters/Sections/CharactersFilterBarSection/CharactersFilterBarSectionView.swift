//
//  CharactersFilterBarSectionView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

import Combine
import SwiftUI

/// The strip of capsules under the search bar.
///
/// It is always on screen, even with nothing applied, because it is the only
/// entry point to the filter sheet: a bar that appeared once a filter existed
/// would have no way of letting the user set the first one.
struct CharactersFilterBarSectionView: View {
    /// Held as the contract, not observed. Exactly as in the list section, the
    /// view model is here so the chips have something to call — the render
    /// pipeline is still publishers -> mapper -> `@State`.
    let viewModel: any CharactersFilterBarSectionViewModelContract

    private let renderModelPublisher: AnyPublisher<CharactersFilterBarRenderModel, Never>

    @State private var renderModel: CharactersFilterBarRenderModel = .empty

    /// Presentation is the *view's* state, not the view model's: nothing outside
    /// this bar can open the sheet, and routing a boolean through a publisher
    /// would make the view model responsible for a piece of UI it never needs to
    /// reason about.
    @State private var isPresentingFilters = false

    init(viewModel: any CharactersFilterBarSectionViewModelContract,
         mapper: CharactersFilterBarSectionMapper) {
        self.viewModel = viewModel
        self.renderModelPublisher = mapper.renderModelPublisher()
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                filtersButton
                ForEach(renderModel.chips) { chip in
                    chipView(chip)
                }
                if renderModel.activeCount > 0 {
                    Button("Clear all") {
                        viewModel.clearAllFilters()
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
            // Seeded from the applied filter every time it opens, so the sheet
            // can never show a draft the list is not already reflecting.
            CharactersFilterSheet(initial: renderModel.filter) { filter in
                viewModel.apply(filter)
            }
        }
    }

    /// The count lives in the label rather than in a badge overlay: it has to
    /// survive Dynamic Type and be read out by VoiceOver, and "Filters, 2" is
    /// exactly what a badge would be trying to say.
    private var filtersButton: some View {
        Button {
            isPresentingFilters = true
        } label: {
            Label(renderModel.activeCount > 0 ? "Filters · \(renderModel.activeCount)" : "Filters",
                  systemImage: "line.3.horizontal.decrease.circle")
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
        .accessibilityLabel("Remove \(chip.title) filter")
    }
}
