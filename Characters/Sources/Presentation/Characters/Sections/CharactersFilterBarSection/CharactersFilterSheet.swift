//
//  CharactersFilterSheet.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

import SwiftUI

/// The four non-search constraints, edited together.
///
/// It works on a **draft** and applies once, on Done. Applying each control as
/// it changed would mean a request per tap — four requests to set four fields,
/// against an API that answers 429 to a client that asks too often — and would
/// make swiping the sheet away an ambiguous gesture instead of a plain cancel.
///
/// The draft carries the applied `name` through untouched, so going through the
/// sheet can never drop what the user typed into the search bar.
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
                    Picker("Status", selection: $draft.status) {
                        Text("Any").tag(CharacterStatus?.none)
                        ForEach(CharacterStatus.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(CharacterStatus?.some(status))
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Gender", selection: $draft.gender) {
                        Text("Any").tag(CharacterGender?.none)
                        ForEach(CharacterGender.allCases, id: \.self) { gender in
                            Text(gender.rawValue.capitalized).tag(CharacterGender?.some(gender))
                        }
                    }
                }

                Section {
                    // Free text. Trimming happens on Done, not per keystroke:
                    // trimming as the user types would eat the space in
                    // "Poopybutthole Sr" the instant it was pressed.
                    TextField("Species", text: text(\.species), prompt: Text("e.g. Human, Alien"))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Type", text: text(\.type), prompt: Text("e.g. Parasite, Clone"))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } footer: {
                    Text("Type is the sub-species the API records, like Parasite or Clone.")
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Resets the four fields only. `name` is not a field, so the
                    // search text survives a reset by construction.
                    Button("Reset") {
                        draft = draft.clearingFields()
                    }
                    .disabled(!draft.hasActiveFields)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // Normalized here, at the one moment it becomes a real
                        // constraint: a filter carrying "   " would send an
                        // empty string to the server and match nothing.
                        onApply(draft.normalized())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// A `String` binding over an optional field.
    ///
    /// `TextField` needs a non-optional `String`, and the filter needs `nil` for
    /// "unconstrained". Doing the conversion in one place means neither side has
    /// to know about the other's representation.
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
