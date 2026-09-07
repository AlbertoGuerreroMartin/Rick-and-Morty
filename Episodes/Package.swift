// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Episodes",
    platforms: [
        .iOS("18.6")
    ],
    products: [
        .library(
            name: "Episodes",
            targets: ["Episodes"]
        ),
    ],
    dependencies: [
        .package(path: "../Networking"),
        .package(path: "../Core"),
        .package(path: "../Storage"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(
            name: "Episodes",
            dependencies: [
                .product(name: "Networking", package: "Networking"),
                .product(name: "Core", package: "Core"),
                .product(name: "Storage", package: "Storage"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ]
        ),
        .testTarget(
            name: "EpisodesTests",
            dependencies: ["Episodes"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
