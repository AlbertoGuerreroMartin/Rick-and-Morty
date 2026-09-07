//
//  EpisodesSearchQueryTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation
import Testing
@testable import Episodes

/// The search is local, so this value *is* the search: what it matches is what
/// the user sees, with no server to blame or to correct it.
@Suite("EpisodesSearchQuery")
struct EpisodesSearchQueryTests {

    // MARK: - Normalization

    @Test("blank text normalizes to no query at all", arguments: [nil, "", " ", "\n", "  \t "] as [String?])
    func blankTextIsNil(text: String?) {
        let query = EpisodesSearchQuery(text: text)

        #expect(query.text == nil)
        #expect(query.isEmpty)
        #expect(query == .empty)
    }

    @Test("surrounding whitespace is trimmed")
    func textIsTrimmed() {
        #expect(EpisodesSearchQuery(text: "  pilot  ").text == "pilot")
        #expect(EpisodesSearchQuery(text: "  pilot  ") == EpisodesSearchQuery(text: "pilot"))
    }

    @Test("the empty query is empty and the default")
    func emptyIsTheDefault() {
        #expect(EpisodesSearchQuery().isEmpty)
        #expect(EpisodesSearchQuery.empty.text == nil)
        #expect(!EpisodesSearchQuery(text: "pilot").isEmpty)
    }

    // MARK: - Matching

    @Test("an empty query matches everything")
    func emptyQueryMatchesEverything() {
        #expect(EpisodesSearchQuery.empty.matches(.make(name: "Pilot")))
        #expect(EpisodesSearchQuery.empty.matches(.make(name: "Anything at all")))
    }

    @Test("the name matches, case-insensitively", arguments: ["lawnmower", "LAWNMOWER", "Dog", "wer Do"])
    func nameMatches(text: String) {
        #expect(EpisodesSearchQuery(text: text).matches(.make(name: "Lawnmower Dog")))
    }

    /// Typing a code is how people jump to a season or to every premiere.
    @Test("the code matches", arguments: ["S03", "s03", "E01", "S03E01"])
    func codeMatches(text: String) {
        #expect(EpisodesSearchQuery(text: text).matches(.make(season: 3, number: 1)))
    }

    /// The air date is the API's own wording, which is how people remember when
    /// something aired: a year, or a month.
    @Test("the air date matches", arguments: ["2013", "December", "december", "2, 2013"])
    func airDateMatches(text: String) {
        #expect(EpisodesSearchQuery(text: text).matches(.make(airDate: "December 2, 2013")))
    }

    @Test("matching ignores diacritics in both directions")
    func matchingIsDiacriticInsensitive() {
        #expect(EpisodesSearchQuery(text: "rasnovan").matches(.make(name: "Râsnovan Rick")))
        #expect(EpisodesSearchQuery(text: "râsnovan").matches(.make(name: "Rasnovan Rick")))
    }

    @Test("a query that matches nothing on the episode returns false")
    func nonMatchingReturnsFalse() {
        let episode = EpisodeModel.make(name: "Pilot", airDate: "December 2, 2013", season: 1, number: 1)

        #expect(!EpisodesSearchQuery(text: "squanch").matches(episode))
        #expect(!EpisodesSearchQuery(text: "S02").matches(episode))
        #expect(!EpisodesSearchQuery(text: "2020").matches(episode))
    }

    /// Deliberately not searched: character ids and images are opaque strings no
    /// user has ever seen, and matching them would produce results nobody could
    /// explain.
    @Test("character ids and images are not searched")
    func charactersAreNotSearched() {
        let episode = EpisodeModel.make(
            name: "Pilot",
            characters: [EpisodeCharacterModel(id: "squanchy",
                                               image: URL(string: "https://example.com/birdperson.jpeg")!)]
        )

        #expect(!EpisodesSearchQuery(text: "squanchy").matches(episode))
        #expect(!EpisodesSearchQuery(text: "birdperson").matches(episode))
    }

    /// `created` is the API's bookkeeping timestamp, never on screen. Searching
    /// it would return 2013 episodes for a query of "2021".
    @Test("the created timestamp is not searched")
    func createdIsNotSearched() {
        let episode = EpisodeModel.make(airDate: "December 2, 2013",
                                        created: Date(timeIntervalSince1970: 1_634_317_224))

        #expect(!EpisodesSearchQuery(text: "2021").matches(episode))
    }
}
