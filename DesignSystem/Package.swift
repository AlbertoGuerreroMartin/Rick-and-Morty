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
    ],
    targets: [
        .target(
            name: "DesignSystem",
            dependencies: [
                .product(name: "Storage", package: "Storage"),
            ]
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: [
                "DesignSystem",
                .product(name: "Storage", package: "Storage"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
