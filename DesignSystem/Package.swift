// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [
        .iOS("18.6")
    ],
    products: [
        .library(
            name: "DesignSystem",
            targets: ["DesignSystem"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.65.1"),
        .package(path: "../Storage"),
        // Image downloads log through Networking's records, not a parallel set of their own.
        .package(path: "../Networking"),
    ],
    targets: [
        .target(
            name: "DesignSystem",
            dependencies: [
                .product(name: "Storage", package: "Storage"),
                .product(name: "Networking", package: "Networking"),
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: [
                "DesignSystem",
                .product(name: "Storage", package: "Storage"),
                .product(name: "Networking", package: "Networking"),
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
