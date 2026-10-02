// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Worm",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "WormCore"),
        .executableTarget(
            name: "Worm",
            dependencies: ["WormCore"]
        ),
        // Diagnostics harness. Not shipped in the app bundle; it exists so the
        // scan engine can be measured and exercised without a window.
        .executableTarget(
            name: "WormDiag",
            dependencies: ["WormCore"]
        ),
        .testTarget(
            name: "WormCoreTests",
            dependencies: ["WormCore"]
        ),
    ]
)