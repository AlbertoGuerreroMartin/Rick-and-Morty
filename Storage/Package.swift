// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Storage",
    platforms: [
        .iOS("18.6")
    ],
    products: [
        .library(
            name: "Storage",
            targets: ["Storage"]
        ),
    ],
    targets: [
        .target(
            name: "Storage"
        ),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Storage"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
