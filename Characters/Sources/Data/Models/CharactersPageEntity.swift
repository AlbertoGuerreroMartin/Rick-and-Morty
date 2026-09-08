//
//  CharactersPageEntity.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 04/09/2026.
//

import Networking

/// One page of characters exactly as the server sent it. Cached as-is, not as
/// `[CharacterModel]`, so the mapper stays a pure, always-applied transformation and
/// `info.next` (which the domain model has nowhere to put) survives.
typealias CharactersPageEntity = GraphQLPageResponse<CharacterEntity>
