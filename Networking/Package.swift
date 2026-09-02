// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [
        .iOS("18.6")
    ],
    products: [
        .library(
            name: "Networking",
            targets: ["Networking"]
        ),
    ],
    targets: [
        .target(
            name: "Networking"
        ),
        .testTarget(
            name: "NetworkingTests",
            dependencies: ["Networking"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
