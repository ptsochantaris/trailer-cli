// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "trailer-cli",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "trailer", targets: ["trailer"])
    ],
    dependencies: [
        .package(url: "https://github.com/ptsochantaris/trailer-ql", branch: "main"),
        .package(url: "https://github.com/ptsochantaris/trailer-json", branch: "main"),
        .package(url: "https://github.com/ptsochantaris/semalot", branch: "main"),
        .package(url: "https://github.com/ptsochantaris/lista", branch: "main")
    ],
    targets: [
        .executableTarget(name: "trailer", dependencies: [
            .product(name: "TrailerQL", package: "trailer-ql"),
            .product(name: "TrailerJson", package: "trailer-json"),
            .product(name: "Semalot", package: "semalot"),
            .product(name: "Lista", package: "lista")
        ])
    ]
)
