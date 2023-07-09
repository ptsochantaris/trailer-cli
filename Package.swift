// swift-tools-version:5.8

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
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0"),
        .package(url: "https://github.com/ptsochantaris/trailer-json", branch: "main"),
        .package(url: "https://github.com/ptsochantaris/trailer-ql", branch: "main"),
        .package(url: "https://github.com/ptsochantaris/lista", branch: "main"),
    ],
    targets: [
        .executableTarget(name: "trailer", dependencies: [
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
            .product(name: "TrailerJson", package: "trailer-json"),
            .product(name: "Lista", package: "lista"),
        ])
    ]
)
