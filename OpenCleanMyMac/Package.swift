// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenCleanMyMac",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "OpenCleanMyMac", targets: ["OpenCleanMyMac"])
    ],
    targets: [
        .executableTarget(
            name: "OpenCleanMyMac",
            path: "Sources/OpenCleanMyMac",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
