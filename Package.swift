// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Snything",
    platforms: [.macOS(.v14)],
    products: [
        .executable(
            name: "Snything",
            targets: ["Snything"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Snything",
            path: "Sources/Snything",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SnythingTests",
            dependencies: ["Snything"],
            path: "Tests/SnythingTests"
        )
    ]
)
