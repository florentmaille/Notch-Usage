// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchUsageCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NotchUsageCore", targets: ["NotchUsageCore"]),
    ],
    targets: [
        .target(
            name: "NotchUsageCore",
            path: "Sources/NotchUsageCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "NotchUsageCoreTests",
            dependencies: ["NotchUsageCore"],
            path: "Tests/NotchUsageCoreTests",
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
