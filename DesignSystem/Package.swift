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
        .package(path: "../Storage"),
        // Image downloads are logged through Networking's records rather than a
        // parallel set of their own: they are HTTP requests, and one inspector
        // showing both is the whole point.
        .package(path: "../Networking"),
    ],
    targets: [
        .target(
            name: "DesignSystem",
            dependencies: [
                .product(name: "Storage", package: "Storage"),
                .product(name: "Networking", package: "Networking"),
            ]
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: [
                "DesignSystem",
                .product(name: "Storage", package: "Storage"),
                .product(name: "Networking", package: "Networking"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
