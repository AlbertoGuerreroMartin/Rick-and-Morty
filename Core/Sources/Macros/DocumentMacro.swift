//
//  DocumentMacro.swift
//  Core
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct DocumentMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let fields: [String] = declaration.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            // drop static/class members
            .filter { !$0.modifiers.contains { $0.name.text == "static" || $0.name.text == "class" } }
            .flatMap { decl in
                decl.bindings.compactMap { binding -> String? in
                    // drop computed properties, and properties whose type is
                    // inferred rather than written out — there is no type syntax
                    // to hand to `GraphQLField.resolve`.
                    guard binding.accessorBlock == nil,
                          let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                          let type = binding.typeAnnotation?.type
                    else { return nil }
                    return #"GraphQLField.resolve("\#(name)", \#(baseType(of: type)).self, depth: depth)"#
                }
            }

        let literals = fields.joined(separator: ", ")

        return [
            """
            static func document(depth: Int) -> String {
                ([\(raw: literals)] as [String?]).compactMap(\\.self).joined(separator: "\\n")
            }
            """
        ]
    }

    /// Peels optionals and arrays off a property's type, so `[Episode]?` resolves
    /// against `Episode`. Whether that base type is a document type is decided at
    /// runtime by `GraphQLField`; the macro cannot know it here.
    private static func baseType(of type: TypeSyntax) -> String {
        var type = type
        while true {
            if let optional = type.as(OptionalTypeSyntax.self) {
                type = optional.wrappedType
            } else if let optional = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
                type = optional.wrappedType
            } else if let array = type.as(ArrayTypeSyntax.self) {
                type = array.element
            } else {
                return type.trimmedDescription
            }
        }
    }
}
