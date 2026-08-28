// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Characters",
    platforms: [
        .iOS("18.6")
    ],
    products: [
        .library(
            name: "Characters",
            targets: ["Characters"]
        ),
    ],
    targets: [
        .target(
            name: "Characters"
        ),
        .testTarget(
            name: "CharactersTests",
            dependencies: ["Characters"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
