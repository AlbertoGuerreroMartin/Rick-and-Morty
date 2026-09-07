//
//  CharactersPaginationFooterView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import SwiftUI

/// The last element of a results section *is* the pagination trigger.
///
/// It only works inside a lazy container — `List`, or a `LazyVStack` in a
/// `ScrollView`. Those build their children lazily, so this view is only
/// instantiated — and its `.task` only runs — when the user has actually
/// scrolled to the bottom. That replaces the usual "is row N - 5 visible?"
/// geometry maths with the framework's own laziness. Placed after a
/// `LazyVGrid` but *outside* a lazy container it would be created on the first
/// frame and chain-load every page.
///
/// `id: loadedCount` re-fires the task when a page lands while the footer is
/// still on screen — a short page, or a tall device — instead of leaving a
/// spinner sitting there forever waiting for a scroll that never comes.
///
/// The `List`-only row modifiers are harmless in a `ScrollView` and are applied
/// unconditionally so the list keeps its look without a second footer.
struct CharactersPaginationFooterView: View {
    let footer: CharactersSectionFooter
    let loadedCount: Int
    let loadNextPage: () async -> Void

    var body: some View {
        switch footer {
        case .loadMore, .loading:
            // One branch for both, deliberately: SwiftUI would otherwise give
            // the two states different identities and cancel the very task that
            // moved `.loadMore` to `.loading`.
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .task(id: loadedCount) {
                    await loadNextPage()
                }
        case .retry:
            VStack(spacing: 8) {
                Text("Couldn't load more characters")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await loadNextPage() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        case .none:
            EmptyView()
        }
    }
}
