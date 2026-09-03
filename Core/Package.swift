// swift-tools-version: 6.3

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [
        .iOS("18.6"),
        // The macro plugin and its tests are compiled for the *host*, so this
        // package — unlike every other one in the workspace — has to build on
        // macOS as well. Nothing in `Core` is iOS-only, so this costs nothing.
        .macOS("15.0"),
    ],
    products: [
        .library(
            name: "Core",
            targets: ["Core"]
        ),
    ],
    dependencies: [
        // 603.x is the swift-syntax release line that matches Swift 6.3.
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0"),
    ],
    targets: [
        // The compiler plugin. It cannot be a product, which is why the macro
        // *declaration* lives in the `Core` library target instead.
        .macro(
            name: "Macros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Core",
            dependencies: ["Macros"]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: [
                "Macros",
                .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
