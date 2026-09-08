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

/// Requires `id`, `name`, `air_date` and a parseable `episode` code (grouping/ordering depend on
/// it). `created` and `characters` are decoration and never fail a row.
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
                            characters: mapCharacters(entity.characters),
                            hboMaxURL: nil)
    }

    // MARK: - Episode code

    /// Splits `S05E10` into `(5, 10)`. Case-insensitive; anchored so `S05` alone does not match.
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

    /// Missing id/image drops the character; missing `name` is kept as `nil` (row falls back to id).
    private func mapCharacters(_ entities: [EpisodeCharacterEntity]?) -> [EpisodeCharacterModel] {
        (entities ?? []).compactMap { entity in
            guard let id = entity.id, let image = entity.image else { return nil }
            return EpisodeCharacterModel(id: id, name: entity.name, image: image)
        }
    }

    // MARK: - Dates

    /// Two formatters: `ISO8601DateFormatter` returns `nil`, not a best effort, for an unconfigured
    /// fractional-seconds component. `nonisolated(unsafe)`: not `Sendable`, never mutated after init.
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

    private func require<T>(_ value: T?, _ property: String) throws -> T {
        guard let value else {
            throw EpisodeEntityMapperError.missingProperty(property)
        }
        return value
    }
}
