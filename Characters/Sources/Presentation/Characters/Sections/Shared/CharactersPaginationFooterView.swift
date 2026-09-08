//
//  CharactersPaginationFooterView.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import SwiftUI

/// The last element of a results section, and also the pagination trigger.
/// Must sit inside a lazy container (`List`/`LazyVStack`), or `.task` fires on the first frame and chain-loads every page.
struct CharactersPaginationFooterView: View {
    let footer: CharactersSectionFooter
    let loadedCount: Int
    let loadNextPage: () async -> Void

    var body: some View {
        switch footer {
        case .loadMore, .loading:
            // One branch for both: separate identities would cancel the task moving `.loadMore` to `.loading`.
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .task(id: loadedCount) {
                    // Re-fires if a page lands while the footer is still on screen.
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
