// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GridForge",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GridForge", targets: ["GridForge"])
    ],
    targets: [
        // Pure-logic library — no AppKit, fully testable
        .target(
            name: "GridForgeCore",
            path: "Sources/GridForgeCore"
        ),
        // App executable — AppKit, AX, UI
        .executableTarget(
            name: "GridForge",
            dependencies: ["GridForgeCore"],
            path: "Sources/GridForge"
        ),
        // Unit tests — GridForgeCore only
        .testTarget(
            name: "GridForgeTests",
            dependencies: ["GridForgeCore"],
            path: "Tests/GridForgeTests"
        )
    ]
)
