// swift-tools-version:5.7.0

import PackageDescription

let package = Package(
    name: "trailer-cli",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "trailer", targets: ["trailer"])
    ],
    targets: [
        .executableTarget(name: "trailer")
    ]
)
