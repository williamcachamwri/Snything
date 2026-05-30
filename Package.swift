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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Snything",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Snything",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "SnythingTests",
            dependencies: ["Snything"],
            path: "Tests/SnythingTests"
        )
    ]
)
