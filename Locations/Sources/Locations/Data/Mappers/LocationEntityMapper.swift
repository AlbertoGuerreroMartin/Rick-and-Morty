//
//  LocationEntityMapper.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Foundation

protocol LocationEntityMapperContract: Sendable {
    func map(_ entity: LocationEntity?) throws -> LocationModel
}

enum LocationEntityMapperError: LocalizedError {
    case noEntityError(String)
    case missingProperty(String)

    var errorDescription: String? {
        switch self {
        case .noEntityError(let entity):
            "Error mapping LocationEntity: entity \(entity) is nil"
        case .missingProperty(let property):
            "Error mapping LocationEntity: missing required \(property) property"
        }
    }
}

/// Turns the server's shape into the domain's, and decides — per location — what
/// this feature cannot draw a circle for.
///
/// The required set is exactly two fields: `id` and `name`. The id is the
/// carousel's identity and what the selection is published as, and the name is the
/// only thing a circle ever says out loud; a location missing either has nothing
/// to be and nothing to be called.
///
/// Everything else is allowed to be absent, and each for its own reason:
///
/// - `type` and `dimension` are **blank for many locations, and the API sends
///   `""` rather than `null`**, so whitespace normalizes to `nil` and the detail
///   simply does not draw the row. The API's own literal `"unknown"` is a
///   different thing entirely — it is a *value*, the name the show gives to a
///   dimension nobody has charted — so it is kept verbatim. `nil` is reserved
///   for "there is no record at all", and only this mapper can tell the two
///   apart.
/// - a resident missing its id or its image is **dropped, not fatal**: the strip
///   is a row of avatars, one that cannot be drawn or keyed is nothing the user
///   could have noticed, and failing a whole location over it would cost a real
///   circle to save a missing thumbnail.
final class LocationEntityMapper: LocationEntityMapperContract {

    func map(_ entity: LocationEntity?) throws -> LocationModel {
        guard let entity else {
            throw LocationEntityMapperError.noEntityError("LocationEntity")
        }

        return LocationModel(id: try require(entity.id, "id"),
                             name: try require(entity.name, "name"),
                             type: Self.normalized(entity.type),
                             dimension: Self.normalized(entity.dimension),
                             residents: mapResidents(entity.residents))
    }

    // MARK: - Residents

    private func mapResidents(_ entities: [LocationResidentEntity]?) -> [LocationResidentModel] {
        (entities ?? []).compactMap { entity in
            guard let id = entity.id,
                  let name = entity.name,
                  let image = entity.image else { return nil }
            return LocationResidentModel(id: id, name: name, image: image)
        }
    }

    // MARK: - Text

    /// Trims whitespace and turns the blank result into `nil`.
    ///
    /// The API answers `""` rather than `null` for a location with no type, and
    /// an empty string is not the same thing as a value: it would draw a
    /// labelled row with nothing after it.
    private static func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// Unwraps `value`, or throws `missingProperty` naming the `property` that was absent.
    private func require<T>(_ value: T?, _ property: String) throws -> T {
        guard let value else {
            throw LocationEntityMapperError.missingProperty(property)
        }
        return value
    }
}
