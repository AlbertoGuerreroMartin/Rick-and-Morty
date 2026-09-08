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

/// Turns the server's shape into the domain's. Required: `id`, `name`, `status`, `species`,
/// `gender`, `image` — stricter than the list's mapper, since a failure here blanks the
/// whole screen. An episode that fails to map is skipped rather than failing the detail.
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

    /// A place with no name is no place at all.
    private func mapPlace(_ entity: CharacterDetailPlace?) -> CharacterDetailPlaceModel? {
        guard let entity, let name = entity.name else { return nil }
        return CharacterDetailPlaceModel(name: name,
                                         type: Self.normalized(entity.type),
                                         dimension: Self.normalized(entity.dimension))
    }

    // MARK: - Episodes

    /// One bad episode costs its own row and nothing else. Order is kept as the API sends it.
    private func mapEpisodes(_ entities: [CharacterDetailEpisode]?) -> [CharacterDetailEpisodeModel] {
        (entities ?? []).compactMap { entity in
            do {
                return try mapEpisode(entity)
            } catch {
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
                                           // Joined in later from JustWatch. See `CharacterDetailUseCase`.
                                           hboMaxURL: nil)
    }

    /// Splits `S05E10` into `(5, 10)`. Case-insensitive; anchored so `Season 5` or `S05` alone
    /// do not match.
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

    /// Trims whitespace and turns the blank result into `nil`. The API sends `""`, not
    /// `null`, for an absent value.
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
