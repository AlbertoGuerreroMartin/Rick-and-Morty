//
//  CharacterDetailModel.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

/// One character, with everything the detail screen shows, in domain terms.
///
/// It is a separate type from `CharacterModel` rather than a superset of it. The
/// list needs five fields and fetches forty-two pages of them; the detail needs
/// eleven and fetches one character. Sharing one model would mean either the
/// list carrying nine properties it never draws — and paying for them in every
/// cached page — or the detail reaching for optionals that are only ever filled
/// in on one screen.
///
/// The optionals are the ones the API genuinely leaves out: `type` is blank for
/// most characters, and `origin` and `location` can be unknown. Everything else
/// is required, and a detail
/// missing one of them is a failed screen rather than a half-drawn one — there
/// is nothing else on this screen to fall back to.
struct CharacterDetailModel: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let status: CharacterStatus
    let species: String
    /// The subspecies or variant, e.g. `Parasite`. `nil` — never `""` — when the
    /// API left it blank, so the info card can drop the row rather than draw an
    /// empty one.
    let type: String?
    let gender: CharacterGender
    let image: URL
    /// Where the character is from. `nil` when the API has no origin record at
    /// all; the string `"unknown"`, which is what the API sends for most
    /// characters, is a *name* and is kept verbatim.
    let origin: CharacterDetailPlaceModel?
    /// Where the character was last seen, same rules as `origin`.
    let location: CharacterDetailPlaceModel?
    /// Every episode the character appears in, in the order the API listed them.
    let episodes: [CharacterDetailEpisodeModel]

    /// The same character with its episodes replaced.
    ///
    /// The HBO Max join happens after both fetches land, so the detail is built
    /// once with linkless episodes and completed here rather than being made
    /// mutable or carried through the mapper in a half-built state. See
    /// `CharacterDetailUseCase`.
    func withEpisodes(_ episodes: [CharacterDetailEpisodeModel]) -> CharacterDetailModel {
        CharacterDetailModel(id: id,
                             name: name,
                             status: status,
                             species: species,
                             type: type,
                             gender: gender,
                             image: image,
                             origin: origin,
                             location: location,
                             episodes: episodes)
    }
}

/// A place as the detail screen knows one: what it is called, what kind of place
/// it is, and which dimension it sits in.
///
/// All three arrive as separate fields and are joined into one line by the info
/// section's mapper rather than here, because "what to show when the dimension
/// is missing" is a copy decision and copy decisions belong where the tests
/// assert them.
struct CharacterDetailPlaceModel: Sendable, Hashable {
    /// Verbatim from the API — including the literal `"unknown"` it sends for a
    /// character with no known origin. Rewriting that into `nil` would throw away
    /// the difference between "the API says it is unknown" and "the API has no
    /// record", and only the first of those is something to show.
    let name: String
    let type: String?
    let dimension: String?
}

/// One episode as the detail screen knows one.
///
/// A deliberately small type rather than the Episodes feature's model. Reusing
/// that one would mean importing a whole feature package for four fields and
/// dragging its character strip into a screen that has no use for it — see
/// `JustWatchShowOffersQuery` for why the two features stay independent.
///
/// `code`, `season` and `number` all come out of the same string on the wire
/// (`S05E10`), and all three are kept. `code` is what the row *shows*, verbatim,
/// because the API's spelling is the one the user recognises from every episode
/// guide they have seen; `season` and `number` are what the HBO Max join is
/// keyed on, and re-parsing them at the point of use would put a regex in the
/// render path.
struct CharacterDetailEpisodeModel: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    /// The air date exactly as the API words it, e.g. `December 2, 2013`.
    ///
    /// Kept as text rather than parsed into a `Date`: it has no time zone and no
    /// time of day, and every use of it here is display. Parsing it would mean
    /// picking a locale to parse *in* and another to format back out, which is
    /// two chances to turn a correct date into a wrong one for no visible gain.
    let airDate: String
    /// The broadcast code as the API spells it, e.g. `S01E05`.
    let code: String
    let season: Int
    /// The episode's number *within its season*, from the code.
    let number: Int
    /// Where to watch this episode on HBO Max, or `nil` when there is nowhere —
    /// or when the lookup that would have found it did not answer.
    ///
    /// It comes from a different server than every other property here, which is
    /// why it is the only one that can be `nil` for no reason the user did
    /// anything about. See `CharacterDetailUseCase`.
    let hboMaxURL: URL?

    /// The same episode with its link attached.
    func withHBOMaxURL(_ url: URL?) -> CharacterDetailEpisodeModel {
        CharacterDetailEpisodeModel(id: id,
                                    name: name,
                                    airDate: airDate,
                                    code: code,
                                    season: season,
                                    number: number,
                                    hboMaxURL: url)
    }
}
