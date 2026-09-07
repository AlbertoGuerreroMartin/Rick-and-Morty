//
//  CharactersQuery+Filter.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 06/09/2026.
//

/// Turns the domain's filter into the operation's variables.
///
/// The translation lives here, in the data layer, so the domain never learns
/// that `gender` travels as a GraphQL enum or that `filter` is a nested input
/// object. It is a `rawValue` hop in both directions because the two enum pairs
/// were deliberately given the same spellings as the schema.
///
/// The one property worth spelling out: **an empty filter must build exactly
/// `CharactersQuery(page:)`**, every other variable `nil`. Cache identity is
/// derived from the document plus the encoded variables, and both drop `nil`
/// optionals — the document builder skips absent properties and `Encodable`
/// synthesis uses `encodeIfPresent`. So an unfiltered page keeps the key it had
/// before this feature existed, and the pages already on disk stay addressable
/// instead of silently ageing out on first launch after the update.
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
