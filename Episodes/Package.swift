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
    targets: [
        .target(
            name: "Episodes"
        ),
        .testTarget(
            name: "EpisodesTests",
            dependencies: ["Episodes"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
