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
    targets: [
        .target(
            name: "Locations"
        ),
        .testTarget(
            name: "LocationsTests",
            dependencies: ["Locations"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
