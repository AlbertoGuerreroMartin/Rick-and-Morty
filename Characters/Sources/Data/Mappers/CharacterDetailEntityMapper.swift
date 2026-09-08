//
//  CharacterDetailEntityMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Foundation

protocol CharacterDetailEntityMapperContract: Sendable {
    func map(_ entity: CharacterDetailEntity?) throws -> CharacterDetailModel
}

enum CharacterDetailEntityMapperError: LocalizedError {
    case noEntityError(String)
    case missingProperty(String)
    /// The `episode` field was present but not shaped like `S05E10`.
    case invalidCode(String)

    var errorDescription: String? {
        switch self {
        case .noEntityError(let entity):
            "Error mapping CharacterDetailEntity: entity \(entity) is nil"
        case .missingProperty(let property):
            "Error mapping CharacterDetailEntity: missing required \(property) property"
        case .invalidCode(let code):
            "Error mapping CharacterDetailEntity: \(code) is not a valid SxxExx episode code"
        }
    }
}

/// Turns the server's shape into the domain's, and decides what the detail
/// screen cannot be drawn without.
///
/// The required set is `id`, `name`, `status`, `species`, `gender` and `image`.
/// It is stricter than the list's mapper on purpose: a character that will not
/// map is one row missing from a list of eight hundred, and it is the *entire*
/// screen here — so a detail that cannot be mapped fails rather than rendering a
/// page with a hole in it. `status` and `gender` are required but can never
/// actually be missing once the field is present: both enums fall back to
/// `unknown` rather than rejecting a spelling this app has not seen.
///
/// `type`, `origin` and `location` are the opposite case, and each is absent
/// for a different reason:
///
/// - `type` is blank for most characters, and the API sends `""` rather than
///   `null`, so whitespace is normalized to `nil` — the info card drops the row
///   instead of drawing an empty one.
/// - a place is `nil` only when the API has *no record*. The literal `"unknown"`
///   it sends for most characters is a name and is kept verbatim: rewriting it
///   would throw away the difference between "the API says unknown" and "there
///   is nothing here", and only the first of those is worth showing.
///
/// Episodes follow `EpisodeEntityMapper`'s rules, one episode at a time, and
/// **an episode that fails is skipped rather than failing the detail**. That is
/// the one place this mapper is lenient, and deliberately so: a hundred-row
/// filmography missing one entry is invisible, while refusing the character over
/// it would blank a screen the user asked for by name.
final class CharacterDetailEntityMapper: CharacterDetailEntityMapperContract {

    func map(_ entity: CharacterDetailEntity?) throws -> CharacterDetailModel {
        guard let entity else {
            throw CharacterDetailEntityMapperError.noEntityError("CharacterDetailEntity")
        }

        return CharacterDetailModel(
            id: try require(entity.id, "id"),
            name: try require(entity.name, "name"),
            status: try require(entity.status.flatMap(CharacterStatus.init(rawValue:)), "status"),
            species: try require(entity.species, "species"),
            type: Self.normalized(entity.type),
            gender: try require(entity.gender.flatMap(CharacterGender.init(rawValue:)), "gender"),
            image: try require(entity.image, "image"),
            origin: mapPlace(entity.origin),
            location: mapPlace(entity.location),
            episodes: mapEpisodes(entity.episode)
        )
    }

    // MARK: - Places

    /// A place with no name is no place at all: the name is the only part of it
    /// the screen shows on its own, and a row reading "· Planet · C-137" with
    /// nothing in front of it would be worse than no row.
    private func mapPlace(_ entity: CharacterDetailPlace?) -> CharacterDetailPlaceModel? {
        guard let entity, let name = entity.name else { return nil }
        return CharacterDetailPlaceModel(name: name,
                                         type: Self.normalized(entity.type),
                                         dimension: Self.normalized(entity.dimension))
    }

    // MARK: - Episodes

    /// One bad episode costs its own row and nothing else.
    ///
    /// The order is the API's, untouched: it lists a character's episodes in
    /// broadcast order, which is the order a filmography reads in, and sorting
    /// them here would be this feature second-guessing an answer that is already
    /// right.
    private func mapEpisodes(_ entities: [CharacterDetailEpisode]?) -> [CharacterDetailEpisodeModel] {
        (entities ?? []).compactMap { entity in
            do {
                return try mapEpisode(entity)
            } catch {
                // Log error without stopping the whole parsing process.
                print("[ERROR] \(error.localizedDescription)")
                return nil
            }
        }
    }

    private func mapEpisode(_ entity: CharacterDetailEpisode) throws -> CharacterDetailEpisodeModel {
        let code = try require(entity.episode, "episode.episode")
        let (season, number) = try parseCode(code)

        return CharacterDetailEpisodeModel(id: try require(entity.id, "episode.id"),
                                           name: try require(entity.name, "episode.name"),
                                           airDate: try require(entity.air_date, "episode.air_date"),
                                           code: code,
                                           season: season,
                                           number: number,
                                           // Always nil here: the link comes from
                                           // JustWatch, a different server this
                                           // mapper knows nothing about, and is
                                           // joined on later. See
                                           // `CharacterDetailUseCase`.
                                           hboMaxURL: nil)
    }

    /// Splits `S05E10` into `(5, 10)`.
    ///
    /// Case-insensitive because the schema promises a format, not a casing, and
    /// a lowercase `s05e10` describes exactly the same episode — refusing it
    /// would drop a row over a detail no user can see. The anchors are what make
    /// this strict where it matters: `Season 5` or `S05` alone do not match, and
    /// so cannot become a row keyed to the wrong episode of the HBO Max join.
    private func parseCode(_ code: String) throws -> (season: Int, number: Int) {
        let pattern = /^S(\d+)E(\d+)$/.ignoresCase()
        guard let match = try? pattern.wholeMatch(in: code),
              let season = Int(match.output.1),
              let number = Int(match.output.2) else {
            throw CharacterDetailEntityMapperError.invalidCode(code)
        }
        return (season, number)
    }

    // MARK: - Text

    /// Trims whitespace and turns the blank result into `nil`.
    ///
    /// The API answers `""` rather than `null` for a character with no subtype,
    /// and an empty string is not the same thing as a value: it would draw a
    /// labelled row with nothing after the colon.
    private static func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// Unwraps `value`, or throws `missingProperty` naming the `property` that was absent.
    private func require<T>(_ value: T?, _ property: String) throws -> T {
        guard let value else {
            throw CharacterDetailEntityMapperError.missingProperty(property)
        }
        return value
    }
}
