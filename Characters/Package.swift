// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Characters",
    platforms: [
        .iOS("18.6")
    ],
    products: [
        .library(
            name: "Characters",
            targets: ["Characters"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.65.1"),
        .package(path: "../Networking"),
        .package(path: "../Core"),
        .package(path: "../Storage"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(
            name: "Characters",
            dependencies: [
                .product(name: "Networking", package: "Networking"),
                .product(name: "Core", package: "Core"),
                .product(name: "Storage", package: "Storage"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .testTarget(
            name: "CharactersTests",
            dependencies: ["Characters"],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
