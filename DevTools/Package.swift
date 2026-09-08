// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "DevTools",
    platforms: [
        .iOS("18.6")
    ],
    products: [
        .library(
            name: "DevTools",
            targets: ["DevTools"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.65.1"),
        .package(path: "../Networking"),
        .package(path: "../Storage"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(
            name: "DevTools",
            dependencies: [
                .product(name: "Networking", package: "Networking"),
                .product(name: "Storage", package: "Storage"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .testTarget(
            name: "DevToolsTests",
            dependencies: [
                "DevTools",
                .product(name: "Networking", package: "Networking"),
                .product(name: "Storage", package: "Storage"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
