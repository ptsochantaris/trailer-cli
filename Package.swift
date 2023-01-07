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
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(name: "trailer", dependencies: [
            .product(name: "AsyncHTTPClient", package: "async-http-client")
        ])
    ]
)
