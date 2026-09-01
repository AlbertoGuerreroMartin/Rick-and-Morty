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
    targets: [
        .target(
            name: "DesignSystem"
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
