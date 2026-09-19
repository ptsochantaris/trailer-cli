// swift-tools-version: 6.4

import PackageDescription

// `platforms` constrains Apple platforms only, so this single manifest also serves the Linux and
// Windows builds described in the README.
let package = Package(
    name: "trailer-cli",
    platforms: [
        .macOS(.v15)
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
        ], swiftSettings: swiftSettings),
        .testTarget(name: "trailerTests", dependencies: ["trailer"], swiftSettings: swiftSettings)
    ]
)

// This is a single-threaded CLI: the whole module defaults to the main actor, and the few genuinely
// concurrent pieces (file I/O, TrailerQL's node parsing) opt out explicitly.
var swiftSettings: [SwiftSetting] {
    [
        .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault")
    ]
}
