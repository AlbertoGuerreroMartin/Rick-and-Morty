// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Locations",
    platforms: [
        .iOS("18.6")
    ],
    products: [
        .library(
            name: "Locations",
            targets: ["Locations"]
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
            name: "Locations",
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
            name: "LocationsTests",
            dependencies: ["Locations"],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
