//
//  CharactersFilter.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

import Foundation

/// The gender values the API accepts as a characters filter.
enum CharacterGender: String, Sendable, Hashable, CaseIterable {
    case female
    case male
    case genderless
    case unknown

    init?(rawValue: String) {
        // Read leniently: the API mixes casing and may add values this app
        // doesn't know, so an unrecognised spelling falls back to unknown.
        switch rawValue.lowercased() {
        case "female": self = .female
        case "male": self = .male
        case "genderless": self = .genderless
        default: self = .unknown
        }
    }
}

/// Every constraint the API accepts on the characters list; `nil` means unconstrained, blank text normalizes to `nil`.
struct CharactersFilter: Sendable, Hashable {
    /// The search bar's text. `nil` when blank after trimming.
    var name: String?
    var status: CharacterStatus?
    /// Free text, trimmed. `nil` when blank.
    var species: String?
    /// Free text, trimmed. `nil` when blank.
    var type: String?
    var gender: CharacterGender?

    static let empty = CharactersFilter()

    init(name: String? = nil,
         status: CharacterStatus? = nil,
         species: String? = nil,
         type: String? = nil,
         gender: CharacterGender? = nil) {
        self.name = Self.normalized(name)
        self.status = status
        self.species = Self.normalized(species)
        self.type = Self.normalized(type)
        self.gender = gender
    }

    /// The four constraints that are not the search bar.
    enum Field: String, Sendable, Hashable, CaseIterable {
        case status
        case species
        case type
        case gender
    }

    /// How many of the four fields are set. Drives the filter button's badge.
    var activeFieldCount: Int {
        Field.allCases.filter { self[field: $0] != nil }.count
    }

    var hasActiveFields: Bool {
        activeFieldCount > 0
    }

    /// True when nothing at all constrains the list — search text included.
    var isEmpty: Bool {
        self == .empty
    }

    /// One line of user-facing copy summarizing the filter, or `nil` when empty.
    var summary: String? {
        let fields = Field.allCases.compactMap { field -> String? in
            self[field: field].map { field == .type ? "Type: \($0)" : $0.capitalized }
        }
        let quotedName = name.map { "\u{201C}\($0)\u{201D}" }

        switch (quotedName, fields.isEmpty) {
        case (let quotedName?, true):
            return quotedName
        case (let quotedName?, false):
            return "\(quotedName) with \(fields.joined(separator: " · "))"
        case (nil, false):
            return fields.joined(separator: " · ")
        case (nil, true):
            return nil
        }
    }

    subscript(field field: Field) -> String? {
        switch field {
        case .status: status?.rawValue
        case .species: species
        case .type: type
        case .gender: gender?.rawValue
        }
    }

    /// Drops one constraint. The search text is never a `Field`.
    mutating func clear(_ field: Field) {
        switch field {
        case .status: status = nil
        case .species: species = nil
        case .type: type = nil
        case .gender: gender = nil
        }
    }

    /// A copy with the four fields cleared and the search text untouched.
    func clearingFields() -> CharactersFilter {
        var copy = self
        Field.allCases.forEach { copy.clear($0) }
        return copy
    }

    /// Re-normalizes free-text fields; for a draft edited field by field.
    func normalized() -> CharactersFilter {
        CharactersFilter(name: name, status: status, species: species, type: type, gender: gender)
    }

    /// A copy with a new search text, normalized.
    func with(name: String?) -> CharactersFilter {
        var copy = self
        copy.name = Self.normalized(name)
        return copy
    }

    /// Trims whitespace and newlines; blank becomes `nil`.
    static func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
