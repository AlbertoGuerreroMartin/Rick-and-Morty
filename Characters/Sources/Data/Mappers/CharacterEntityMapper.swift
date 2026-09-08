//
//  CharacterEntityMapper.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Foundation

protocol CharacterEntityMapperContract: Sendable {
    func map(_ entity: CharacterEntity?) throws -> CharacterModel
}

enum CharacterEntityMapperError: LocalizedError {
    case noEntityError(String)
    case missingProperty(String)

    var errorDescription: String? {
        switch self {
        case .noEntityError(let entity):
            "Error mapping CharacterEntity: entity \(entity) is nil"
        case .missingProperty(let property):
            "Error mapping CharacterEntity: missing required \(property) property"
        }
    }
}

final class CharacterEntityMapper: CharacterEntityMapperContract {
    func map(_ entity: CharacterEntity?) throws -> CharacterModel {
        guard let entity else {
            throw CharacterEntityMapperError.noEntityError("CharacterEntity")
        }

        return CharacterModel(id: try require(entity.id, "id"),
                              name: try require(entity.name, "name"),
                              status: try require(entity.status.flatMap(CharacterStatus.init(rawValue:)), "status"),
                              species: try require(entity.species, "species"),
                              image: try require(entity.image, "image"),
                              location: try mapLocation(entity.location))
    }

    func mapLocation(_ entity: CharacterLocationEntity?) throws -> CharacterLocation {
        guard let entity else {
            throw CharacterEntityMapperError.noEntityError("location (CharacterLocationEntity)")
        }

        return CharacterLocation(name: try require(entity.name, "location.name"),
                                 dimension: entity.dimension)
    }

    /// Unwraps `value`, or throws `missingProperty` naming the `property` that was absent.
    private func require<T>(_ value: T?, _ property: String) throws -> T {
        guard let value else {
            throw CharacterEntityMapperError.missingProperty(property)
        }
        return value
    }
}
