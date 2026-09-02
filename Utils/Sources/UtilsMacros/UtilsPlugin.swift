//
//  UtilsPlugin.swift
//  Utils
//
//  Created by Alberto Guerrero Martin on 01/09/2026.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct UtilsPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        DocumentMacro.self,
    ]
}
