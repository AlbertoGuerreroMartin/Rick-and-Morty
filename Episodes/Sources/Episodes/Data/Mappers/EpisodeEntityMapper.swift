//
//  EpisodeEntityMapper.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

protocol EpisodeEntityMapperContract: Sendable {
    func map(_ entity: EpisodeEntity?) throws -> EpisodeModel
}

enum EpisodeEntityMapperError: LocalizedError {
    case noEntityError(String)
    case missingProperty(String)
    /// The `episode` field was present but not shaped like `S05E10`.
    case invalidCode(String)

    var errorDescription: String? {
        switch self {
        case .noEntityError(let entity):
            "Error mapping EpisodeEntity: entity \(entity) is nil"
        case .missingProperty(let property):
            "Error mapping EpisodeEntity: missing required \(property) property"
        case .invalidCode(let code):
            "Error mapping EpisodeEntity: \(code) is not a valid SxxExx episode code"
        }
    }
}

/// Turns the server's shape into the domain's, and decides — per episode — what
/// this feature cannot draw a row without.
///
/// The required set is `id`, `name`, `air_date` and a *parseable* `episode`
/// code. The code is required because it is not decoration: the screen groups
/// rows by season and orders them by number, both of which come out of that
/// string, so an episode whose code will not parse has no place to be put. That
/// is why an unparseable code is `invalidCode` rather than a silent fallback to
/// season 0 — a fabricated season would quietly invent a group on screen.
///
/// `created` and `characters` are the opposite case: both are decoration, and
/// neither can fail a row. A missing or unparseable timestamp is simply `nil`,
/// and a character missing its id or its image is dropped from the strip while
/// the rest of the episode maps normally.
final class EpisodeEntityMapper: EpisodeEntityMapperContract {

    func map(_ entity: EpisodeEntity?) throws -> EpisodeModel {
        guard let entity else {
            throw EpisodeEntityMapperError.noEntityError("EpisodeEntity")
        }

        let code = try require(entity.episode, "episode")
        let (season, number) = try parseCode(code)

        return EpisodeModel(id: try require(entity.id, "id"),
                            name: try require(entity.name, "name"),
                            airDate: try require(entity.air_date, "air_date"),
                            code: code,
                            season: season,
                            number: number,
                            created: Self.date(from: entity.created),
                            characters: mapCharacters(entity.characters))
    }

    // MARK: - Episode code

    /// Splits `S05E10` into `(5, 10)`.
    ///
    /// Case-insensitive because the schema promises a format, not a casing, and
    /// a lowercase `s05e10` describes exactly the same episode — refusing it
    /// would drop a row over a detail no user can see. The anchors are what make
    /// this strict where it matters: `Season 5` or `S05` alone do not match, and
    /// so cannot become a half-parsed row in the wrong group.
    private func parseCode(_ code: String) throws -> (season: Int, number: Int) {
        let pattern = /^S(\d+)E(\d+)$/.ignoresCase()
        guard let match = try? pattern.wholeMatch(in: code),
              let season = Int(match.output.1),
              let number = Int(match.output.2) else {
            throw EpisodeEntityMapperError.invalidCode(code)
        }
        return (season, number)
    }

    // MARK: - Characters

    /// A character with no id or no image is dropped, not fatal.
    ///
    /// The strip is a row of avatars: one that cannot be drawn or keyed is
    /// nothing the user could have noticed, and failing the whole episode over
    /// it would cost a real row to save a missing thumbnail.
    private func mapCharacters(_ entities: [EpisodeCharacterEntity]?) -> [EpisodeCharacterModel] {
        (entities ?? []).compactMap { entity in
            guard let id = entity.id, let image = entity.image else { return nil }
            return EpisodeCharacterModel(id: id, image: image)
        }
    }

    // MARK: - Dates

    /// Two formatters rather than one, because the API is not consistent about
    /// fractional seconds: `created` arrives as `2021-10-15T17:00:24.105Z`
    /// today, and `ISO8601DateFormatter` returns `nil` — not a close-enough date
    /// — when the string carries a component the options did not ask for. Trying
    /// the strict-with-fraction reading first and the plain one second means
    /// either spelling parses, and anything else is simply `nil`.
    ///
    /// They are `static let` so the pair is built once: `ISO8601DateFormatter`
    /// is expensive to create and this runs per episode, on every read, for the
    /// whole catalogue.
    ///
    /// `nonisolated(unsafe)` because the type is not `Sendable` and Swift 6 has
    /// no way to know that these two are never mutated after the closure above
    /// returns. Foundation's date formatters are documented as safe for
    /// concurrent *use*; it is configuration that is not thread-safe, and there
    /// is none here. The alternative — building a formatter per call — costs
    /// two allocations per episode on every read of a 51-row catalogue.
    private nonisolated(unsafe) static let fractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private nonisolated(unsafe) static let internetDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func date(from text: String?) -> Date? {
        guard let text else { return nil }
        return fractionalSecondsFormatter.date(from: text) ?? internetDateTimeFormatter.date(from: text)
    }

    /// Unwraps `value`, or throws `missingProperty` naming the `property` that was absent.
    private func require<T>(_ value: T?, _ property: String) throws -> T {
        guard let value else {
            throw EpisodeEntityMapperError.missingProperty(property)
        }
        return value
    }
}
