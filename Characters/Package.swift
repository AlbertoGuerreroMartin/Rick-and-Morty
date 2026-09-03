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
    dependencies: [
        .package(path: "../Networking"),
        .package(path: "../Utils"),
    ],
    targets: [
        .target(
            name: "Characters",
            dependencies: [
                .product(name: "Networking", package: "Networking"),
                .product(name: "Utils", package: "Utils"),
            ]
        ),
        .testTarget(
            name: "CharactersTests",
            dependencies: ["Characters"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
