//
//  CharactersFilter.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

import Foundation

/// The gender values the API accepts as a characters filter.
///
/// It lives in the domain rather than being reused from the data layer's
/// `CharactersQueryGender` for the same reason `CharacterStatus` does: the
/// presentation layer picks one of these in a menu, and a screen has no business
/// importing a query type to do it. The raw values match the schema, so the
/// mapping down to the query is a `rawValue` and nothing else.
enum CharacterGender: String, Sendable, Hashable, CaseIterable {
    case female
    case male
    case genderless
    case unknown
}

/// Every constraint the API accepts on the characters list, in one value.
///
/// The whole search-and-filter feature is server-first: the list on screen is
/// always "the complete, paginated result for *this* filter". Modelling the five
/// constraints as one `Hashable` value is what makes that statement checkable —
/// a reload is a filter change, a no-op is `new == applied`, and the cache key
/// downstream is derived from the same five fields. Five loose properties on the
/// view model could disagree with each other; this cannot.
///
/// `nil` means "unconstrained", and blank text is always normalized to `nil`, so
/// a filter carrying `species: "   "` — which would send an empty string to the
/// server and match nothing — is unrepresentable in practice.
struct CharactersFilter: Sendable, Hashable {
    /// The search bar's text. `nil` when blank after trimming.
    var name: String?
    var status: CharacterStatus?
    /// Free text, trimmed. `nil` when blank.
    var species: String?
    /// Free text, trimmed. `nil` when blank.
    var type: String?
    var gender: CharacterGender?

    /// No constraints at all: the plain, unfiltered character list.
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

    /// The four constraints that are *not* the search bar.
    ///
    /// They are grouped because the UI treats them as a set the search text is
    /// not part of: they get a chip each, a count on the "Filters" button, and a
    /// "Clear all" that must never wipe what the user typed.
    enum Field: String, Sendable, Hashable, CaseIterable {
        case status
        case species
        case type
        case gender
    }

    /// How many of the four fields are set. Drives the badge on the filter
    /// button and the "Clear all" affordance.
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

    /// The whole filter as one line of user-facing copy, or `nil` when there is
    /// nothing to describe.
    ///
    /// It carries the search text as well as the fields because it exists for
    /// exactly one caller — the "no characters found" state — and telling the
    /// user *why* nothing matched is only useful if it names everything that was
    /// asked for: `“rick” with Alive · Human`.
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

    /// The value of one of the four fields, as text. `nil` when unconstrained.
    ///
    /// A subscript rather than four `switch`es: `activeFieldCount`, `summary`
    /// and the chip mapper all need "read field X", and repeating the switch in
    /// each of them is three places to forget a new case in.
    subscript(field field: Field) -> String? {
        switch field {
        case .status: status?.rawValue
        case .species: species
        case .type: type
        case .gender: gender?.rawValue
        }
    }

    /// Drops one constraint. The search text is never a `Field`, so this cannot
    /// silently throw it away.
    mutating func clear(_ field: Field) {
        switch field {
        case .status: status = nil
        case .species: species = nil
        case .type: type = nil
        case .gender: gender = nil
        }
    }

    /// A copy with the four fields cleared and the search text untouched.
    ///
    /// "Clear all" means the filters the user opened a sheet to set, not the
    /// word they are still typing in the search bar.
    func clearingFields() -> CharactersFilter {
        var copy = self
        Field.allCases.forEach { copy.clear($0) }
        return copy
    }

    /// A copy with every free-text field trimmed and blanks turned into `nil`.
    ///
    /// The initializer already does this, so a filter that was *built* is always
    /// normalized; this is for one that was edited field by field — the filter
    /// sheet's draft, which lets the user type freely and tidies up on Done.
    func normalized() -> CharactersFilter {
        CharactersFilter(name: name, status: status, species: species, type: type, gender: gender)
    }

    /// A copy with a new search text, normalized.
    func with(name: String?) -> CharactersFilter {
        var copy = self
        copy.name = Self.normalized(name)
        return copy
    }

    /// Trims whitespace and newlines, and turns the blank result into `nil`.
    ///
    /// Every text that reaches a filter goes through here, so `""` and `"  "`
    /// can never become a constraint the server would match nothing against.
    static func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
