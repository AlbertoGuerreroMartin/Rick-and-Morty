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

/// Turns the server's shape into the domain's. Only `id` and `name` are required.
///
/// `type`/`dimension`: API sends `""` (not `null`) when blank, normalized here to `nil`;
/// the literal `"unknown"` is a real value and kept as-is. A resident missing id or image
/// is dropped rather than failing the whole location.
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

    /// Trims whitespace; a blank result becomes `nil`.
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
