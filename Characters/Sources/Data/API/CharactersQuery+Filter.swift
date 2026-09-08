//
//  CharactersQuery+Filter.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

/// An empty filter must build exactly `CharactersQuery(page:)`: cache identity drops `nil`
/// variables, so an unfiltered page keeps its pre-existing key.
extension CharactersQuery {
    init(filter: CharactersFilter, page: Int) {
        self.init(page: page,
                  name: filter.name,
                  status: filter.status.flatMap { CharactersQueryStatus(rawValue: $0.rawValue) },
                  species: filter.species,
                  type: filter.type,
                  gender: filter.gender.flatMap { CharactersQueryGender(rawValue: $0.rawValue) })
    }
}
