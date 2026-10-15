// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenCleanMyMac",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "OpenCleanMyMac", targets: ["OpenCleanMyMac"]),
        // Same binary; install/symlink as `maccleaner` for PATH usage.
        .executable(name: "maccleaner", targets: ["OpenCleanMyMac"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "OpenCleanMyMac",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/OpenCleanMyMac",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
