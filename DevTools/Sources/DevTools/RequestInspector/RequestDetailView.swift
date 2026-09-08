//
//  RequestDetailView.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import SwiftUI
import UIKit

/// One entry in full: the same text the Xcode console would have shown.
struct RequestDetailView: View {
    let entry: RequestInspectorEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section(title: entry.kind == .cache ? "Cache" : "Request", text: entry.requestText)
                if let responseText = entry.responseText {
                    section(title: "Response", text: responseText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(entry.status.text)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Copy", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = copyText
                }
            }
        }
    }

    var copyText: String {
        [entry.requestText, entry.responseText]
            .compactMap { $0 }
            .joined(separator: "\n\n")
    }

    private func section(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
