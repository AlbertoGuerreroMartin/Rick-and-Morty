//
//  CharactersFilterSheet.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

import SwiftUI

/// The four non-search constraints, edited as a draft and applied once on Done, since each request risks a 429.
struct CharactersFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CharactersFilter
    private let onApply: (CharactersFilter) -> Void

    init(initial: CharactersFilter, onApply: @escaping (CharactersFilter) -> Void) {
        _draft = State(initialValue: initial)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    Picker("Status", selection: $draft.status) {
                        Text("Any").tag(CharacterStatus?.none)
                        ForEach(CharacterStatus.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(CharacterStatus?.some(status))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Gender") {
                    Picker("Gender", selection: $draft.gender) {
                        Text("Any").tag(CharacterGender?.none)
                        ForEach(CharacterGender.allCases, id: \.self) { gender in
                            Text(gender.rawValue.capitalized).tag(CharacterGender?.some(gender))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Species") {
                    TextField("Species", text: text(\.species), prompt: Text("e.g. Human, Alien"))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Type") {
                    TextField("Type", text: text(\.type), prompt: Text("e.g. Parasite, Clone"))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        draft = draft.clearingFields()
                    }
                    .disabled(!draft.hasActiveFields)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onApply(draft.normalized())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// A `String` binding over an optional filter field, for `TextField`.
    private func text(_ keyPath: WritableKeyPath<CharactersFilter, String?>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: { draft[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }
}

#Preview {
    CharactersFilterSheet(initial: CharactersFilter(name: "rick", status: .alive, species: "Human")) { _ in }
}
