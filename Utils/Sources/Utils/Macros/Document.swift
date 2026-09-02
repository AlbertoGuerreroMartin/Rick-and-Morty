//
//  Document.swift
//  Utils
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

/// Generates a `document` selection set from the type's stored properties.
///
/// GraphQL asks you to spell out every field you want. For a network entity that
/// list is exactly its stored properties, so writing it by hand is duplication
/// that silently rots the moment somebody adds a property.
///
/// ```swift
/// @Document
/// struct CharacterEntity {
///     let id: String
///     let name: String
///     let species: String
///     let image: URL?
/// }
///
/// CharacterEntity.document  // "id\nname\nspecies\nimage"
/// ```
///
/// Static, class and computed properties are skipped — only the stored instance
/// properties, which are the ones that have to come off the wire. A property
/// whose type is written out and itself conforms to `GraphQLDocumentConvertible`
/// expands into a nested selection set, bounded by `depth`:
///
/// ```swift
/// CharacterEntity.document  // "id\nname\norigin { name dimension }"
/// ```
///
/// The generated member is `internal`, and no protocol conformance is added:
/// declare `: GraphQLDocumentConvertible` yourself where you need it.
@attached(member, names: named(document))
public macro Document() = #externalMacro(module: "UtilsMacros", type: "DocumentMacro")
