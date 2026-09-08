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
                Section {
                    Picker(selection: $draft.status) {
                        Text("Any", bundle: .module).tag(CharacterStatus?.none)
                        ForEach(CharacterStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(CharacterStatus?.some(status))
                        }
                    } label: {
                        Text("Status", bundle: .module)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Status", bundle: .module)
                }

                Section {
                    Picker(selection: $draft.gender) {
                        Text("Any", bundle: .module).tag(CharacterGender?.none)
                        ForEach(CharacterGender.allCases, id: \.self) { gender in
                            Text(gender.displayName).tag(CharacterGender?.some(gender))
                        }
                    } label: {
                        Text("Gender", bundle: .module)
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Gender", bundle: .module)
                }

                Section {
                    TextField(text: text(\.species), prompt: Text("e.g. Human, Alien", bundle: .module)) {
                        Text("Species", bundle: .module)
                    }
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                } header: {
                    Text("Species", bundle: .module)
                }

                Section {
                    TextField(text: text(\.type), prompt: Text("e.g. Parasite, Clone", bundle: .module)) {
                        Text("Type", bundle: .module)
                    }
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                } header: {
                    Text("Type", bundle: .module)
                }
            }
            .navigationTitle(Text("Filters", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        draft = draft.clearingFields()
                    } label: {
                        Text("Reset", bundle: .module)
                    }
                    .disabled(!draft.hasActiveFields)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onApply(draft.normalized())
                        dismiss()
                    } label: {
                        Text("Done", bundle: .module)
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
