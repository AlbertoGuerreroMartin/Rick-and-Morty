// swift-tools-version: 6.3

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [
        .iOS("18.6"),
        // The macro plugin and its tests compile for the host, so this package must build on
        // macOS too.
        .macOS("15.0"),
    ],
    products: [
        .library(
            name: "Core",
            targets: ["Core"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.65.1"),
        // 603.x is the swift-syntax release line that matches Swift 6.3.
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0"),
    ],
    targets: [
        // Compiler plugin; can't be a product, so the macro declaration lives in `Core` instead.
        .macro(
            name: "Macros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .target(
            name: "Core",
            dependencies: ["Macros"],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: [
                "Core",
                "Macros",
                .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
