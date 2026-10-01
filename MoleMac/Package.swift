// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MoleMac",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MoleCore"),
        .executableTarget(
            name: "MoleMac",
            dependencies: ["MoleCore"]
        ),
        // Diagnostics harness. Not shipped in the app bundle; it exists so the
        // scan engine can be measured and exercised without a window.
        .executableTarget(
            name: "MoleDiag",
            dependencies: ["MoleCore"]
        ),
        .testTarget(
            name: "MoleCoreTests",
            dependencies: ["MoleCore"]
        ),
    ]
)