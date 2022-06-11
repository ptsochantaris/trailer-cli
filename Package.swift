// swift-tools-version:5.6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
