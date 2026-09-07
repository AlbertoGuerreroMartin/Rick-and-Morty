//
//  RequestDetailView.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import SwiftUI
import UIKit

/// One entry in full: the same text the Xcode console would have shown.
///
/// Monospaced and selectable, and with a copy button, because the thing a
/// developer does with a failing request is paste it into a bug report or a
/// `curl`. Reformatting the body would defeat that — what is shown has to be
/// what crossed the wire.
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

    /// Both halves together: a request without its response, or the other way
    /// round, is rarely enough to explain anything.
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
