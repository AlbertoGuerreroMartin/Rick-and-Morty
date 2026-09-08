//
//  Document.swift
//  Core
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

/// Generates a `document` selection set from the type's stored properties, skipping static,
/// class, and computed ones. A property whose type conforms to `GraphQLDocumentConvertible`
/// expands into a nested selection, bounded by `depth`.
///
/// ```swift
/// @Document
/// struct CharacterEntity { let id: String; let name: String }
/// // CharacterEntity.document == "id\nname"
/// ```
///
/// Generates an `internal` member; conform to `GraphQLDocumentConvertible` yourself where needed.
@attached(member, names: named(document))
public macro Document() = #externalMacro(module: "Macros", type: "DocumentMacro")
